#!/bin/bash

# Bash script to mirror shared local OSX printers to Airprint using lpstat and ipprint
# Tested in MacOSX 10.10 Yosemite

# Does not use dns-sd as it frequently fails inside bash scripting
# Printer is registered as Airprint_Queuename @ OSXComputerName with underscores
# instead of a pretty printer service name with spaces and hyphens

# Limitation: The URF string may vary by printer capabilities. See https://wiki.debian.org/AirPrint

declare -a printers

# Find OSXComputerName
OSXComputerName=`scutil --get ComputerName`

# Get enabled printer queue names from lpstat
# Note lpstat returns OSX queuename with underscores, not the dns-sd service name
lpList=$( lpstat -p | grep "enabled" | awk -F " " '{print $2}' )

# Use ippfind to return OSX queuenames (URI) with underscores
ippList=$( ippfind --local | awk -F "printers/" '{print $2}' )

# Find only those printers being shared (i.e. not also in the ipplist)
for i in $lpList; do
  for j in $ippList; do
    if [[ $i == $j ]]; then
      printers+=$i
    fi
  done
done

if [ ${#printers[@]} -eq 0 ]; then
  echo "No printers found. Make sure a printer on this computer is shared."
  exit 1
fi

# For every printer: extract the rp queue, the location (note) and whether it is a duplex printer using dns-sd -L
# Then register each shared printer by name using dns-sd -R
for i in $printers; do
  rp="rp=printers/$i"
  note=$(lpstat -l -p "$i" | grep "Location: " | awk -F "Location: " '{print $2}')

  # Servicename is typically in the lpstat Description field - could be used in ippfind below
  # and/or to register prettier airprint service name
  #servicename=$(lpstat -l -p "$i" | grep "Description: " | awk -F "Description: " '{print $2}')

  # Determine Duplex using ippfind (use --path instead of -n as $i isn't a service name)
  Duplex=$(ippfind _ipp._tcp --local --path "$i" --txt-Duplex t)
  if [ ${#Duplex} -ge 1 ]; then
    Duplex="Duplex=T"
  else
    Duplex="Duplex=F"
  fi

  # Set these attributes manually for Airprint compatibility
  pdl="pdl=application/pdf,application/postscript,image/urf"

  # The URF may vary by printer capabilities. See https://wiki.debian.org/AirPrint
  URF="URF=W8,CP1,RS300-600,DM3,SRGB24"

  # Register the printer as Airprint - the minimalist dns-sd command for Airprint is:
  #dns-sd -R "PrinterName @ OSXComputerName” _ipp._tcp,_universal . 631 txtvers=1 qtotal=1 rp=printers/PrinterOSXQueueName note=The_office_@_OSXComputerName pdl=application/pdf,application/postscript,image/urf URF=W8,CP1,RS300-600,DM3,SRGB24
  dns-sd -R "Airprint_$i @ $OSXComputerName" _ipp._tcp,_universal . 631 txtvers=1 qtotal=1 $rp note="$note" $pdl $URF $Duplex & sleep 0 &
done

sleep 2; echo
