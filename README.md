Current Cost Listener
=====================

This is a perl script that listens to XML data coming from the current cost CC 128. 
It parses the XML and writes the data to a mysql database.  It should be fairly easy to modify
the code to store the data elsewhere.  Simply change the "addConsumption" and "addTemperature"
subroutines.

The script assumes you've got the included udev rule installed (store it in /etc/udev/rules.d/).
This creates a device file /dev/CurrentCost and also runs the script (located at /usr/bin/currentcost.pl)
automatically whenever you plug in the device.
