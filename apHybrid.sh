#!/bin/bash

# Bash script to mirror shared OSX printers to Airprint
# Tested in MacOSX 10.10 Yosemite

# Hybrid script between using dns-sd (frequently fails), falling back to lp/ipp unix tools

# Limitation: The URF string may vary by printer capabilities. See https://wiki.debian.org/AirPrint

declare -a printers
declare -a services

# Find OSXComputerName
OSXComputerName=`scutil --get ComputerName`

# Kill any previously added printers with dns-sd
killall dns-sd

# Pipe list of bonjour printer services local to $OSXComputerName to "/tmp/BonjourPrinters.txt"
dns-sd -B _ipp._tcp local | colrm 1 73 | grep -v 'Instance Name' | sort | uniq | grep ${OSXComputerName} > /tmp/BonjourPrinters.txt & sleep 1 & killall dns-sd

# Save internal field separator
OLDIFS=$IFS
IFS=$(echo -en "\n\b")

# List printers
servicesList=$(< /tmp/BonjourPrinters.txt)
printersList=$servicesList

#Trim @ ComputerName, spaces and hyphens to underlines
printersList=("${printersList[@]/ @*/}")
printersList=("${printersList[@]/ /_}")
printersList=("${printersList[@]/-/_}")

# For debugging
#printersList=''

# dns-sd -B can return disabled printers so:
# Get active printer queue names from lpstat
# Note the queuename is not the service name, which is in the description field
lpList=$( lpstat -p | grep "enabled" | awk -F " " '{print $2}' )

# Use ippfind to return queue (URI) names with underscores (not service names with spaces and hyphens)
ippList=$( ippfind --local | awk -F "printers/" '{print $2}' )

# If dns-sd -B failed or didn't find any printers, use ippList instead
if [ ${#printersList} -eq 0 ]; then
  printersList=$ippList
fi

#if ippList is empty, exit
if [ ${#printersList} -eq 0 ]; then
  echo "No printers found. Make sure a printer on this computer is shared."
  exit 1
fi

# Remove any disabled or non-shared printers from list of printers (and printer services)
for i in $lpList; do
  k=0;
  for j in $printersList; do
    if [[ $i == $j ]]; then
      printers+=$i
      # add service also only if non-empty (ie not using ipplist instead)
      if [ ${#servicesList[@]} -ge 1 ]; then
        services+=${servicesList[$k]}
      fi
    fi
    ((k++))
  done
done

# For debugging:
#echo "s: $services"
#echo "p: $printers"

# For every printer: extract the rp queue, the location (note) and whether it is a duplex printer using dns-sd -L
# Then register each shared printer by name using dns-sd -R
k=0
for i in $printers; do
  service=$services[$k]
  #if using ippList, serivices is blank, so try to get it from lpstat Description
  if [ ${#service} -lt 1 ]; then
    servicename=$(lpstat -l -p "$i" | grep "Description: " | awk -F "Description: " '{print $2}')
    service="$servicename @ $OSXComputerName"
  fi
  ((k++))
  outp=''
  printf "Searching for printer $service"
  j=0
  while [ ${#outp} -eq 0 ]; do
    ((j++))
    # this expects a service name @ OSXComputerName
    outp=$(dns-sd -L "$service" _ipp._tcp local | grep 'rp=' & sleep 1 & killall dns-sd)
    printf "."
    if [ $j -eq 15 ]; then
      outp2=$(lpstat -p "$i" | grep "printer $i")
      if [ ${#outp2} -ge 1 ]; then
        note=$(lpstat -l -p "$i" | grep "Location: " | awk -F "Location: " '{print $2}' )
        # Determine Duplex using ippfind
        Duplex=$(ippfind _ipp._tcp --local --path "$i" --txt-Duplex t)
        if [ ${#Duplex} -ge 1 ]; then
          Duplex="Duplex=T"
        else
          Duplex="Duplex=F"
        fi

        # Replace spaces with underlines
        note=${note// /_}

        # Leading at trailing expression important for regex below after while loop
        outp=" rp=printers/$i note=$note $Duplex "
      fi
    fi
  done
  printf "\n\n"

  # Extract the options to preserve (rp, note, Duplex)
  rp=`echo $outp | sed 's/.*\(rp=[^[[:space:]]*\)[[:space:]].*/\1/'`
  note=`echo $outp | sed 's/.*\(note=[^[[:space:]]*\)[[:space:]].*/\1/'`
  Duplex=`echo $outp | sed 's/.*\(Duplex=[^[[:space:]]*\)[[:space:]].*/\1/'`

  # rp should always be present but note and duplex are optional
  # If the previous sed substitution fails, it returns itself instead of empty
  if [[ $note == $outp ]]; then
    note=""
  fi
  if [[ $Duplex == $outp ]]; then
    Duplex="Duplex=F"
  fi

  # Replace spaces with underlines
  note=${note// /_}

  # Set these attributes manually for Airprint compatibility
  pdl="pdl=application/pdf,application/postscript,image/urf"

  # The URF may vary by printer capabilities. See https://wiki.debian.org/AirPrint
  URF="URF=W8,CP1,RS300-600,DM3,SRGB24"

  # For debugging:
  #echo $outp > "$outp $rp $note $Duplex $pdl $URF"

  # Register the printer as Airprint - the minimalist dns-sd command for Airprint is:
  #dns-sd -R "PrinterName @ OSXComputerName” _ipp._tcp,_universal . 631 txtvers=1 qtotal=1 rp=printers/PrinterOSXQueueName note=The_office_@_OSXComputerName pdl=application/pdf,application/postscript,image/urf URF=W8,CP1,RS300-600,DM3,SRGB24
  dns-sd -R "Airprint_$i @ $OSXComputerName" _ipp._tcp,_universal . 631 txtvers=1 qtotal=1 $rp $note $pdl $URF $Duplex & sleep 0 &

done

IFS=$OLDIFS

sleep 2; echo
