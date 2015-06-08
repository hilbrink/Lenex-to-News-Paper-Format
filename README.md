# Lenex-to-News-Paper-Format


Usage: lenex_to_newspaper.rb [options]

    -f, --finals                     only list finals
    -p, --places N                   only list first N swimmers (excludes '-d' option)
    -d, --list-disqualified          also list the disqualified swimmers 
    -l, --lenexfile N                required: lenex XML (uncompressed)
    -c, --clubs N,M                  optional: Club Code (default 'RFN')
        --listclubs                  optional: list all clubcodes in the lenex files


example: ./lenex_to_newspaper.rb -l Morges.lxf  -p 5 -c RFN,CNCF 

result: this will extra all the results for the given LXF file (which is compressed XML) for RFN and CNCF for those swimmers who were either 1,2,3,4, or 5 placed.
