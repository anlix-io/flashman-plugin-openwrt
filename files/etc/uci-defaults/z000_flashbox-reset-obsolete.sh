#!/bin/sh

# Reset blockscan rule
A=$(uci -X show firewall | grep "path='/etc/firewall.blockscan'" | \
    awk -F '.' '{ print "firewall."$2 }')
if [ "$A" ]
then
  uci delete $A
fi
# Reset ssh rule
A=$(uci -X show firewall | \
    grep "firewall\..*\.name='\(anlix-ssh\|custom-ssh\)'" | \
    awk -F '.' '{ print "firewall."$2 }')
if [ "$A" ]
then
  uci delete $A
fi
