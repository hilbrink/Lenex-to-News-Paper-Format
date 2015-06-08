#!/usr/bin/env ruby
# author: Niels Hilbrink (c) 2015

require 'nokogiri'
require 'open-uri'
require 'zip'

require 'optparse'

options = {}
options[:onlyfinals] = false # default option
options[:firstN] = 0 #default option (0 = list all)
options[:listdisqualified] = false #do not list the disqualified swimmers
options[:clubcodes] = "RFN"

#Translation (French - lenex file is in English)
translation_fr = {"FLY" => "Papillon", "BACK" => "Dos", "BREAST" => "Brasse", "FREE" => "Libre", "MEDLEY" => "4Nages", 
  "TIM" => "Finale Directe", "PRE" => "Eliminatoire", "FIN" => "Finale", 
  "YEAR" => "ans", "ANDLESS" => "et moins", "ANDMORE" => "et plus", "F" => "Dames", "M" => "Messieurs"}
  
translation_nl = {"FLY" => "Vlinderslag", "BACK" => "Rugslag", "BREAST" => "Schoolslag", "FREE" => "Vrijeslag", "MEDLEY" => "Wisselslag", 
    "TIM" => "Directe Finale", "PRE" => "Series", "FIN" => "Finale", 
    "YEAR" => "jaar", "ANDLESS" => "en jonger", "ANDMORE" => "en ouder", "F" => "Dames", "M" => "Heren"}  
#set the right language
translation = translation_fr


age_group_sort_order=["11 #{translation["YEAR"]} #{translation["ANDLESS"]}", "11 #{translation["YEAR"]}", "12 #{translation["YEAR"]} #{translation["ANDLESS"]}", "12 #{translation["YEAR"]}", "13 #{translation["YEAR"]} #{translation["ANDLESS"]}", "13 #{translation["YEAR"]}", 
  "29 #{translation["YEAR"]} #{translation["ANDLESS"]}", "11-12 #{translation["YEAR"]}", "12-13 #{translation["YEAR"]}", "13-14 #{translation["YEAR"]}", "14-15 #{translation["YEAR"]}", 
  "15-16 #{translation["YEAR"]}", "16-29 #{translation["YEAR"]}", "17 #{translation["YEAR"]} #{translation["ANDMORE"]}", "18 #{translation["YEAR"]} #{translation["ANDMORE"]}", 
  "30-34 #{translation["YEAR"]}", "35-39 #{translation["YEAR"]}", "40-44 #{translation["YEAR"]}", "45-49 #{translation["YEAR"]}", "Open"]
gender_sort_order=["F", "M"]
stroke_sort_order=["FLY", "BACK", "BREAST", "FREE", "MEDLEY"]
stroke_distance_sort_order=["25m", "50m", "100m", "200m", "400m", "800m", "1500m"]

OptionParser.new do |opts|
  opts.banner = "Usage: lenex_results_newspaper.rb [options]"

  opts.on("-f", "--finals", "only list finals") do |v|
    options[:onlyfinals] = v
  end
  
  opts.on("-p N", "--places N", Integer, "only list first N swimmers (excludes \'-d\' option)") do |v|
    options[:firstN] = v
  end
  
  opts.on("-d", "--list-disqualified", "also list the disqualified swimmers ") do |v|
    options[:listdisqualified] = v
  end
  
  opts.on("-l N", "--lenexfile N", "required: lenex XML (uncompressed)") do |v|
    options[:lenexfile] = v
  end
  
  opts.on("-c N", "--clubs N,M", "optional: Club Code (default 'RFN')") do |v|
    options[:clubcodes] = v
  end
  
  opts.on("--listclubs", "optional: list all clubcodes in the lenex files") do |v|
    options[:listclubs] = v
  end
  
  opts.on
  
end.parse!

raise OptionParser::MissingArgument if options[:lenexfile].nil?


puts options

# get the 1st file in the compressed archive
zip_file = Zip::File.open(options[:lenexfile]).entries.reject(&:directory?).first  

# open the XML file and parse it through nokogiri
doc = Nokogiri::XML(zip_file.get_input_stream{|is| is.read })


if options[:listclubs] then
  doc.xpath("//CLUB").each do |club|
    puts "#{club['code']} \t #{club['name']}"
  end
  exit
end


results=[]

# Read all the swimmers + event information
options[:clubcodes].split(",").each do |club| 
  doc.xpath("//CLUB[@code='#{club}']").each do |club|
    club_name =  club['name']
    club.xpath('.//ATHLETE').each do |swimmer|
      name = "#{swimmer['firstname']} #{swimmer['lastname']}".encode('utf-8') 
      swimmer.xpath('.//RESULT').each do |result|
        doc.xpath("//EVENT[@eventid='#{result['eventid']}']").each do |event|
          gender      = swimmer['gender']
          birthdate   = swimmer['birthdate']
          agemax      = doc.at_xpath("//EVENTS/EVENT[@eventid='#{result["eventid"]}']//RANKING[@resultid='#{result["resultid"]}']").parent.parent['agemax'].to_i
          agemin      = doc.at_xpath("//EVENTS/EVENT[@eventid='#{result["eventid"]}']//RANKING[@resultid='#{result["resultid"]}']").parent.parent['agemin'].to_i
        
          ((agemax == agemin) ? ((agemax == -1) ? agegroup = "Open" : agegroup = "#{agemin} #{translation["YEAR"]}") : (agemin == -1) ? agegroup = "#{agemax} #{translation["YEAR"]} #{translation["ANDLESS"]}" : ((agemax == -1) ? agegroup = "#{agemin} #{translation["YEAR"]} #{translation["ANDMORE"]}" : agegroup = "#{agemin}-#{agemax} #{translation["YEAR"]}"))
        
          distance    = event.at_xpath('./SWIMSTYLE')['distance']+"m"
          stroke      = translation[event.at_xpath('./SWIMSTYLE')['stroke']]
          place       = doc.at_xpath("//RANKING[@resultid='#{result["resultid"]}']")['place'].to_i
          time        = result['swimtime'].gsub(":", "'").gsub('.', '"')[3..-1].sub!(/^[0]*'*/,'')
          round       = translation[doc.at_xpath("//EVENT[@eventid='#{result["eventid"]}']")['round']]
          status      = result['status']
        
        
          r = {club: club_name, gender: gender, name: name, age_group: agegroup, distance: distance, stroke: stroke, round: round, place: place, time: time, status: status}
        
          #puts r        
          #don't add this result if we're looking for finals this event wasn't swum during a final or direct final
          next if (!(round.eql?(translation["FIN"]) or round.eql?(translation["TIM"])) and options[:onlyfinals])
        
          #don't add this result if we don't want to see disqualified results (or any other result where the status field isn't empty)
          next if ((!options[:listdisqualified] and !status.nil?) or (!status.nil? and place.eql?(-1) and options[:firstN] > 0))
        
          # if the position(place) is larger than firstN (which has to be larger than 0), and status is not empty (i.e. not disq)
          next if (place > options[:firstN] and options[:firstN] > 0) 
    
      
          results.push(r)
        
        end #event loop
      end #result loop
    end #swimmer loop
  end #club
end #clubs

  
#1st loop - the strokes
stroke_sort_order.each do |stroke|

  # look if we have any entries for this stroke
  swimmer_strokes = results.select {|swimmer| swimmer[:stroke].eql?(translation[stroke])}
  next if swimmer_strokes.size == 0 # well, there are no entries for this stroke, so we move on to the next one
  #puts stroke


  #2nd loop - the distance
  stroke_distance_sort_order.each do |distance|
    swimmer_strokes_distance = swimmer_strokes.select {|swimmer| swimmer[:distance] == distance}
    next if swimmer_strokes_distance.size == 0 # well, there are no entries for this distance, so we move on to the next one
    #puts swimmer_strokes_distance
  
    print "\e[1m#{translation['FIN']+" " if options[:onlyfinals]}#{distance} #{translation[stroke]} \e[0m"
  
    #3th loop gender
    gender_sort_order.each do |gender|
      swimmer_strokes_distance_gender = swimmer_strokes_distance.select {|swimmer| swimmer[:gender] == gender}
      next if swimmer_strokes_distance_gender.size == 0 # well, there are no entries for this gender, so we move on to the next one
      
      #print "\e[1m#{translation[gender]} \e[0m"
    
      #4th loop - the age_group 
      age_group_sort_order.each do |age_group|
        swimmer_strokes_distance_gender_agegroup = swimmer_strokes_distance_gender.select {|swimmer| swimmer[:age_group] == age_group}
        next if swimmer_strokes_distance_gender_agegroup.size == 0 # well, there are no entries for this age_group, so we move on to the next one
    
        swimmers = swimmer_strokes_distance_gender_agegroup.select {|swimmer| swimmer[:age_group] == age_group}.sort_by{|a| a[:place]}
        #puts age_group
        next if swimmers.size == 0 # well, there are no entries for this age_group, so we move on to the next one
      
        #swimmers.sort!{|a,b| b[:place] <=> a[:place]}
      
        print "\e[1m#{translation[gender]} #{age_group}:\e[0m"
      
        disq_swimmers = []
        swimmers.each do |swimmer|
          if swimmer[:place].eql?(-1) then
            disq_swimmers.push("disq. #{swimmer[:name]} #{swimmer[:time]} ")
          else
            print "#{swimmer[:place]}. #{swimmer[:name]} (#{swimmer[:club]}) #{swimmer[:time]}. " 
          end
        end
      
        disq_swimmers.each do |d| 
          print d
        end
      
        # debug
        #puts swimmer
      
      
      end #gender loop
    
    end #age_group loop
    print ("\n\n") #print newline
  end #distance loop
  
end #stroke loop
