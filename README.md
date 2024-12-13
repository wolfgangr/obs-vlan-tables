# obs-vlan-tables
Retrieve tabular view of port assignment and filter database entries from Observium 802.1Q vlan data

## Why?
[Observium](https://www.observium.org/) is a great tool fo network surveillance.  
There are others, too, of course, but this was the one I found meeting most of my needs and easiest to get up and running on debian 12.  
The plan is to install a spatially extended, low user, low budget, growing IoT-gadget Installation based on 802.1Q vlans on my farm premises.  
Backbone is built form HP 1810 / 1820 switches, router is a 5*1GB openWRT on x86 (thin client hardware).

While most of the information collected by observium has a decent view in it's GUI, two formats I considered particularily missing:  
- tabular view of **vlan aware port assignemnt** for all (or selected) number of devices
- tabular view of the **filter database**, with vlans to reach a specific target, identified by its MAC-Adress

It's implemented by two command line scripts:
- `obs_print_vlan_ports.pl`
  - vlan IDs in columns
  - devices in rows
  - port assignment to vlan per device in table entries
     
- `obs_print_vlan_fdb.pl`
  - devices in columns
  - mac address of targets in rows
  - vlan, by which the mac can be seen by device in table entries

Both scripts are quite similiar in operation
- get some command line configuration
- load credentials to read observium database (mysql / MariaDB)
- retrieve and reindex data
- optionally filter some of the information
- output as ascii-table, csv, perl-Dump or html

The output of -? is mirrored in the help directory.  
In cgi-bin, there are wrappers to serve both scripts in a web server (tested with apache2)

## Disclaimer
Early develeopment work!  
Current State: _looks like it might work for me_  
Expect nothing but the worst.   
Before any test, carefully scrutinize the source for undesired side effects.  
It's always good practise to test with minimum access rights and a read-only user to observium database.


