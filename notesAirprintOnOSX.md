# OSX AirPrint service for non-AirPrint printers

This is a quick command line way to broadcast an AirPrint service for a shared printer that doesn’t support it on OSX Yosemite (10.10). Printer sharing must be on as it announces a shared printer as an AirPrint printer.

***

The key was simplicity and minimalism in the AirPrint description.

Notes:

1. Turn printer sharing on and identify the printer spool name
2. Issuing a minimalist, stripped down dns-sd command with fewer attributes than bonjour or the printer broadcasts
3. The rp name must be the same exact queuename as it is on OSX or it won’t find the printer
4. Note that the Duplex=T is printer-specific here; e.g. other printers might have Color=T
5. Determining the correct pdl and URF attributes. An Avahi xml file may be helpful here, generated in a vm or elsewhere
6. Note that the dns-sd won't broadcast when the OSX computer is asleep
7. Running avahi on a NAS, router or other low-power linux box might be a solution to the OSX sleep problem (though possibly slow)

***

Important resources

Apple Airprint Bonjour specs: https://developer.apple.com/bonjour/printing-specification/bonjourprinting-1.2.pdf
Debian Avahi Airprint docs: https://wiki.debian.org/AirPrint

***

From the Avahi Airprint docs: "The URF key is one of extensions to the Bonjour Printing Specification mentioned previously. (It can be deduced from US 20110194124 that CP is MAX COPIES, MT is MEDIA TYPES, OB is OUTPUT BINS, OF is FINISHINGS, PQ is PRINT QUALITIES, RS is RESOLUTIONS, SRGB is COLOR SPACES, W is BIT DEPTHS, DM is DUPLEX SUPPORT and IS is INPUT SLOTS).

The pdl (Page Description Language) key is important. It lists the only MIME types the printer will accept for printing. With or without AirPrint enabled the Envy 4502 will not process a PostScript or PDF document sent to it. AirPrint adds nothing to this printer's capability to deal with document types its firmware is not built to cope with.

Note the last entry in the pdl key. image/urf is a fallback MIME type for the client to send to guarantee printing takes place and it is obligatory for it to be accepted by a printer claiming AirPrint compatibility. image/urf is raster data; there are no officially published details about it but it has been reverse engineered."

***

Some other useful repos

Python/Avahi: https://github.com/tjfontaine/airprint-generate
Bash: https://github.com/Macdeviant/iOS-AirPrint-for-Mac
Router: https://github.com/arpancj/airprint

***

When testing from the command line, the minimalist dns-sd command that worked for me

dns-sd -R "Brother DCP @ OSXComputerNameHere” _ipp._tcp,_universal . 631 txtvers=1 qtotal=1 rp=printers/Brother_DCP pdl=application/pdf,application/postscript,image/urf note=“The office @ OSXComputerNameHere" URF="W8,CP1,RS300-600,DM3,SRGB24" Duplex=T & sleep 0 &

***

Bonjour Sleep Proxy on an Apple Router might help with the sleep issue

https://support.apple.com/en-us/HT201960
