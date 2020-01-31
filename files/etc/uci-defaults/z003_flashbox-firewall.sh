#!/bin/sh

# Set firewall rules
uci set firewall.@defaults[-1].input="ACCEPT"
uci set firewall.@defaults[-1].output="ACCEPT"
uci set firewall.@defaults[-1].forward="REJECT"
uci set firewall.@defaults[-1].flow_offloading="1"
# Lan
uci set firewall.@zone[0].input="ACCEPT"
uci set firewall.@zone[0].output="ACCEPT"
uci set firewall.@zone[0].forward="REJECT"
uci set firewall.@zone[0].mtu_fix="1"
# Wan
uci set firewall.@zone[1].input="REJECT"
uci set firewall.@zone[1].output="ACCEPT"
uci set firewall.@zone[1].forward="REJECT"
uci set firewall.@zone[1].mtu_fix="1"
# Block port scan (stealth mode)
if [ -f /etc/firewall.blockscan ]
then
  uci add firewall include
  uci set firewall.@include[-1].path='/etc/firewall.blockscan'
fi
# SSH access 
uci add firewall rule
uci set firewall.@rule[-1].enabled="1"
uci set firewall.@rule[-1].target="ACCEPT"
uci set firewall.@rule[-1].proto="tcp"
uci set firewall.@rule[-1].dest_port="36022"
uci set firewall.@rule[-1].name="anlix-ssh"
uci set firewall.@rule[-1].src="wan"
# DMZ
A=$(uci show firewall | grep "@zone\[.\].name='dmz'")
if [ -z "$A" ]
then
  uci -q add firewall zone
  uci set firewall.@zone[-1].name="dmz"
  uci set firewall.@zone[-1].input="REJECT"
  uci set firewall.@zone[-1].output="ACCEPT"
  uci set firewall.@zone[-1].forward="REJECT"
  uci set firewall.@zone[-1].subnet="192.168.43.128/25"
  uci -q add firewall forwarding
  uci set firewall.@forwarding[-1].src='dmz'
  uci set firewall.@forwarding[-1].dest='wan'
  uci add firewall forwarding
  uci set firewall.@forwarding[-1].src='lan'
  uci set firewall.@forwarding[-1].dest='dmz'
  uci -q add firewall rule
  uci set firewall.@rule[-1].name="dmz-dns"
  uci set firewall.@rule[-1].src='dmz'
  uci set firewall.@rule[-1].proto='tcpudp'
  uci set firewall.@rule[-1].dest_port='53'
  uci set firewall.@rule[-1].target='ACCEPT'
  uci -q add firewall rule
  uci set firewall.@rule[-1].name="dmz-dhcp"
  uci set firewall.@rule[-1].src='dmz'
  uci set firewall.@rule[-1].proto='udp'
  uci set firewall.@rule[-1].dest_port='67'
  uci set firewall.@rule[-1].target='ACCEPT'
fi

uci commit firewall

exit 0
