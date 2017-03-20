# airprint-for-osx
A Bash scripts to advertise a OSX shared non-AirPrint printer as AirPrint printer using unix tools only

This project contains three command-line tools (scripts) which may be helpful to others who are attempting to get iOS AirPrint 
to print to non-AirPrint ready printers. 

3 scripts are currently provided as I have found that Apple's dns-sd tool to be unreliable in bash (and is noted as such 
on the man page).

### Known Limitations
1. The AirPrint specification given is minimalistic, giving the fewest attributes needed to work.
2. Because Apple's AirPrint URF specification is unpublished, the URF may need to be modified before working with any 
particular printer. This URF has been tested on Brother DCP series printers. A postscript-compatible printer might also 
require additional pdl attributes. More advanced scripts would attempt to construct the URF and pdl strings by querying 
the printer.
3. These scripts rely on inferred logic from observing the behavior of OSX. They may be brittle, break, and need to be hacked,
especially when the OS is updated.

## Airprint.sh
A bash script that discovers any shared, enabled, local OSX printers via lpstat and ippfind unix tools. 
Via ippfind it determines whether the printer is duplex capable; this could work for color and other printer attributes.
It then uses dns-sd -R to multicast the shared printer's OSX queue as an AirPrint capable queue. This appears to be reliable.

## apDnssd.sh
A bash script that discovers any shared, local Bonjour OSX printers via the dns-sd tool (dns-sd-B). 
The list of printers is culled using lp-stat so that it only advertises enabled printers.
Dns-sd -L is used to extract the queuename, the location and whether the printer is duplex capable. 
It then uses dns-sd -R to multicast the shared printer's OSX queue as an AirPrint capable queue. 
This script is unreliable due to problems with running dns-sd from bash.

## apHybrid.sh
This bash script is a blend of the previous two scripts. Should dns-sd fail, it falls back on the common unix CUPS tools to
determine the printer name, status and attributes. This was initially an attempt to use the unix tools to compensate for the 
shortcomings of the tool dns-sd in scripted contexts, and led to the attempt to gather the printer information entirely 
without using dns-sd. It may now prove to be the most reliable method.

#### Last Tested
Mar 20 2017 OSX 10.10.5

