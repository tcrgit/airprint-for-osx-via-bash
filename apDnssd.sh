#!/bin/bash

# Bash script to mirror shared local OSX printers to Airprint using dns-sd
# Tested in MacOSX 10.10 Yosemite

# One known problem is that dns-sd sometimes fails to work inside bash scripts
# If so issuing it at the command-line and rerunning the script seems to fix it
# or use the Airprint.sh script to mirror printers to Airprint using only lpstat and ippfind

# Limitation: The URF string may vary by printer capabilities. See https://wiki.debian.org/AirPrint

# Find OSXComputerName
OSXComputerName=`scutil --get ComputerName`

# Kill any previously added printers with dns-sd
killall dns-sd

# Pipe list of bonjour printer services local to $OSXComputerName to "/tmp/BonjourPrinters.txt"
dns-sd -B _ipp._tcp local | colrm 1 73 | grep -v 'Instance Name' | sort | uniq | grep ${OSXComputerName} > /tmp/BonjourPrinters.txt & sleep 1 & killall dns-sd

# Save internal field separator
OLDIFS=$IFS
IFS=$(echo -en "\n\b")

# List printer services
printers=$(< /tmp/BonjourPrinters.txt)

if [ ${#printers} -eq 0 ]; then
  echo "No bonjour printers found. Make sure a printer on this computer is shared and "
  echo "try issuing the following commands."
  echo "dns-sd -B _ipp._tcp local"
  echo "./apDnssd.sh"
  exit 1
fi

# For every printer: extract the rp queue, the location (note) and whether it is a duplex printer using dns-sd -L
# Then register each shared printer by name using dns-sd -R
for i in $printers; do
  #convert pretty service name to queuename for lpstat
  queuename="${i// @*/}"
  queuename="${queuename// /_}"
  queuename="${queuename//-/_}"
  # See whether printer is enabled by finding it by queuename in lpstat
  printerEnabled=$(lpstat -p "$queuename" | grep "enabled")
  if [ ${#printerEnabled} -ge 1 ]; then
    printf "Searching for printer $i"
    outp=''
    j=0
    while [ ${#outp} -eq 0 ]; do
      ((j++))
      # dns-sd expects "service name @ OSXComputerName"
      outp=$(dns-sd -L "$i" _ipp._tcp local | grep 'rp=' & sleep 1 & killall dns-sd)
      printf "."
      # If dns-sd has failed 5 times
      if [ $j -eq 15 ]; then
        # Sometimes dns-sd -L fails. Scripting using dns-sd is apparently unsupported.
        # But if dns-sd -L has recently run, it works
        echo
        echo "Printer not found. Unable to register. Make sure printer sharing is on"
        echo "and try issuing the following commands to rerun: "
        echo "dns-sd -L '$i' _ipp._tcp local 1> /dev/null & sleep 1 & killall dns-sd"
        echo "./apDnssd.sh"
        exit 1
      fi
    done
    printf "\n\n"

    # Extract the options to preserve (rp, note, Duplex)
    rp=$(echo $outp | sed 's/.*\(rp=[^=]*\)[[:space:]].*/\1/')
    note=$(echo $outp | sed 's/.*\(note=[^=]*\)[[:space:]].*/\1/')
    Duplex=$(echo $outp | sed 's/.*\(Duplex=[^=]*\)[[:space:]].*/\1/')

    # rp should always be present but note and duplex are optional
    # If the previous sed substitution fails, it returns itself instead of empty
    if [[ $note == $outp ]]; then
      note=""
    fi
    if [[ $Duplex == $outp ]]; then
      Duplex="Duplex=F"
    fi

    # Replace spaces with underscores in the note to avoid needing to quote it
    note=${note// /_}

    # Set these attributes manually for Airprint compatibility
    pdl="pdl=application/pdf,application/postscript,image/urf"

    # The URF may vary by printer capabilities. See https://wiki.debian.org/AirPrint
    URF="URF=W8,CP1,RS300-600,DM3,SRGB24"

    # Register the printer as Airprint - the minimalist dns-sd command for Airprint is:
    #dns-sd -R "PrinterName @ OSXComputerName” _ipp._tcp,_universal . 631 txtvers=1 qtotal=1 rp=printers/PrinterOSXQueueName note=The_office_@_OSXComputerName pdl=application/pdf,application/postscript,image/urf URF=W8,CP1,RS300-600,DM3,SRGB24
    dns-sd -R "Airprint $i" _ipp._tcp,_universal . 631 txtvers=1 qtotal=1 $rp $note $pdl $URF $Duplex & sleep 0 &
  fi
done

IFS=$OLDIFS

sleep 2; echo
