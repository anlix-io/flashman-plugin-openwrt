#!/bin/sh

. /usr/share/flashman_init.conf
. /lib/functions.sh
. /usr/share/functions.sh

HARDWARE_MODEL=$(get_hardware_model)
SYSTEM_MODEL=$(get_system_model)
CLIENT_MAC=$(get_mac)
HOSTNAME=$(echo $CLIENT_MAC | sed -e "s/:/-/g")
MAC_LAST_CHARS=$(echo $CLIENT_MAC | awk -F: '{ print $5$6 }')
DISTRIBID=$(head -1 /etc/openwrt_release | awk -F = '{ print $2 }')

# Wireless password cannot be empty or have less than 8 chars
if [ "$FLM_PASSWD" == "" ] || [ $(echo "$FLM_PASSWD" | wc -m) -lt 9 ]
then
  FLM_PASSWD=$(echo $CLIENT_MAC | sed -e "s/://g")
fi

firstboot() {
  log "FIRSTBOOT" "First boot start -> MAC $CLIENT_MAC"

  uci set system.@system[-1].timezone="BRT3BRST,M10.3.0/0,M2.3.0/0"
  uci set system.@system[-1].hostname="$HOSTNAME"
  uci set system.@system[-1].cronloglevel="9"
  uci commit system

  uci set system.ntp.enabled="1"
  uci set system.ntp.enable_server="0"
  uci -q delete system.ntp.server
  uci add_list system.ntp.server="$NTP_SVADDR"
  uci commit system
  /etc/init.d/system restart
  /etc/init.d/sysntpd enable
  /etc/init.d/sysntpd restart
  log "FIRSTBOOT" "System and NTP Configured"

  # Set firewall rules
  uci set firewall.@defaults[-1].input="ACCEPT"
  uci set firewall.@defaults[-1].output="ACCEPT"
  uci set firewall.@defaults[-1].forward="REJECT"
  uci commit firewall

  # Lan
  uci set firewall.@zone[0].input="ACCEPT"
  uci set firewall.@zone[0].output="ACCEPT"
  uci set firewall.@zone[0].forward="REJECT"
  uci commit firewall

  # Wan
  uci set firewall.@zone[1].input="ACCEPT"
  uci set firewall.@zone[1].output="ACCEPT"
  uci set firewall.@zone[1].forward="REJECT"
  uci commit firewall

  # DMZ
  A=$(uci show firewall | grep "@zone\[.\].name='dmz'")
  if [ -z "$A" ] 
  then
    uci set network.dmz=interface
    uci set network.dmz.proto='static'
    uci set network.dmz.netmask='255.255.255.0'
    uci set network.dmz.ip6assign='60'
    uci set network.dmz.ifname='@lan'
    uci set network.dmz.ipaddr='192.168.43.1'
    uci commit network

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

    uci set dhcp.dmz=dhcp
    uci set dhcp.dmz.interface='dmz'
    uci set dhcp.dmz.dynamicdhcp='0'
    uci set dhcp.dmz.leasetime='1h'
    uci commit dhcp

    log "FIRSTBOOT" "DMZ Configured"
  fi

  #Block Port Scan (stealth mode)
  A=$(uci -X show firewall | grep "path='/etc/firewall.blockscan'" | awk -F '.' '{ print "firewall."$2 }')
  if [ -z "$A" ]
  then 
    uci delete $A
  fi
  if [ -f /etc/firewall.blockscan ]
  then
    uci add firewall include
    uci set firewall.@include[-1].path='/etc/firewall.blockscan'
  fi
  uci commit firewall

  # SSH access 
  A=$(uci -X show firewall | grep "firewall\..*\.name='\(anlix-ssh\|custom-ssh\)'" | awk -F '.' '{ print "firewall."$2 }')
  if [ -z "$A" ]
  then 
    uci delete $A
  fi
  uci add firewall rule
  uci set firewall.@rule[-1].enabled="1"
  uci set firewall.@rule[-1].target="ACCEPT"
  uci set firewall.@rule[-1].proto="tcp"
  uci set firewall.@rule[-1].dest_port="36022"
  uci set firewall.@rule[-1].name="anlix-ssh"
  uci set firewall.@rule[-1].src="wan"
  uci commit firewall

  [ "$(uci get dropbear.@dropbear[0])" != 'dropbear' ] && uci add dropbear dropbear
  uci set dropbear.@dropbear[0]=dropbear
  uci set dropbear.@dropbear[0].PasswordAuth=off
  uci set dropbear.@dropbear[0].RootPasswordAuth=off
  uci set dropbear.@dropbear[0].Port=36022
  uci set dropbear.@dropbear[0].Interface=wan

  [ "$(uci get dropbear.@dropbear[1])" != 'dropbear' ] && uci add dropbear dropbear
  uci set dropbear.@dropbear[1]=dropbear
  uci set dropbear.@dropbear[1].PasswordAuth=off
  uci set dropbear.@dropbear[1].RootPasswordAuth=off
  uci set dropbear.@dropbear[1].Port=36022
  uci set dropbear.@dropbear[1].Interface=lan

  uci commit dropbear
  /etc/init.d/dropbear restart
  log "FIRSTBOOT" "Dropbear Configured"

  # Configure WiFi default SSID and password
  ssid_value=$(uci get wireless.@wifi-iface[0].ssid)
  encryption_value=$(uci get wireless.@wifi-iface[0].encryption)
  if [ "$encryption_value" = "" ] || { [ "$encryption_value" = "none" ] && { [ "$ssid_value" = "OpenWrt" ] || [ "$ssid_value" = "LEDE" ]; }; }
  then
    if [ "$FLM_SSID_SUFFIX" == "none" ]
    then
      #none
      setssid="$FLM_SSID"
    else
      #lastmac
      setssid="$FLM_SSID$MAC_LAST_CHARS"
    fi

    if [ "$SYSTEM_MODEL" = "MT7628AN" ]
    then
      log "FIRSTBOOT" "Wireless MT7628AN"
      touch /etc/config/wireless
      uci set wireless.radio0=wifi-device

      uci set wireless.@wifi-device[0].type="ralink"
      # Power goes from 0 to 100 in mt7628 (maybe we need to change uci2dat?)
      uci set wireless.@wifi-device[0].txpower="100"
      uci set wireless.@wifi-device[0].variant="mt7628"
      # Disable the interface! mt7628 use a dat file, we only get the parameters from here
      uci set wireless.@wifi-device[0].disabled="1"
      uci set wireless.default_radio0=wifi-iface
      uci set wireless.@wifi-iface[0].ifname="ra0"
      uci set wireless.@wifi-iface[0].mode="ap"
      uci set wireless.@wifi-iface[0].network="lan"
      uci set wireless.@wifi-iface[0].device="radio0"

      if [ "$HARDWARE_MODEL" = "ARCHERC20" ]
      then
        #5GHz
        uci set wireless.radio1=wifi-device
        uci set wireless.@wifi-device[1].type="ralink"
        uci set wireless.@wifi-device[1].txpower="100"
        uci set wireless.@wifi-device[1].variant="mt7610e"
        uci set wireless.@wifi-device[1].disabled="1"
        uci set wireless.default_radio1=wifi-iface
        uci set wireless.@wifi-iface[1].ifname="rai0"
        uci set wireless.@wifi-iface[1].mode="ap"
        uci set wireless.@wifi-iface[1].network="lan"
        uci set wireless.@wifi-iface[1].device="radio1"
        uci set wireless.@wifi-iface[1].ssid="$setssid"
        uci set wireless.@wifi-iface[1].encryption="psk2"
        uci set wireless.@wifi-iface[1].key="$FLM_PASSWD"
      fi
    else
      uci set wireless.@wifi-device[0].type="mac80211"
      uci set wireless.@wifi-device[0].txpower="17"
      uci set wireless.@wifi-device[0].disabled="0"
      # 5GHz
      uci set wireless.@wifi-device[1].disabled="0"
      uci set wireless.@wifi-device[1].type="mac80211"
      uci set wireless.@wifi-device[1].channel="36"
      uci set wireless.@wifi-iface[1].ssid="$setssid"
      uci set wireless.@wifi-iface[1].encryption="psk2"
      uci set wireless.@wifi-iface[1].key="$FLM_PASSWD"
    fi
    uci set wireless.@wifi-device[0].channel="$FLM_24_CHANNEL"
    uci set wireless.@wifi-device[0].hwmode="11n"
    uci set wireless.@wifi-device[0].country="BR"
    uci set wireless.@wifi-device[0].htmode="HT40"
    uci set wireless.@wifi-iface[0].ssid="$setssid"
    uci set wireless.@wifi-iface[0].encryption="psk2"
    uci set wireless.@wifi-iface[0].key="$FLM_PASSWD"
    uci commit wireless
  fi

  if [ "$SYSTEM_MODEL" = "MT7628AN" ]
  then
    uci set system.led_wifi_led.dev="ra0"
    uci set system.led_wlan2g.dev="ra0"
    uci commit system
    /usr/bin/uci2dat -d radio0 -f /etc/wireless/mt7628/mt7628.dat > /dev/null
    LOWERMAC=$(echo $CLIENT_MAC | awk '{ print tolower($1) }')
    insmod /lib/modules/`uname -r`/mt7628.ko mac=$LOWERMAC
    echo "mt7628 mac=$LOWERMAC" >> /etc/modules.d/50-mt7628
    cp /sbin/mtkwifi /sbin/wifi
  fi
  
  if [ "$HARDWARE_MODEL" = "ARCHERC20" ]
  then 
    uci set system.led_wlan5g=led
    uci set system.led_wlan5g.name='wlan5g'
    uci set system.led_wlan5g.sysfs='archer-c20-v4:green:wlan5g'
    uci set system.led_wlan5g.trigger='netdev'
    uci set system.led_wlan5g.dev='rai0'
    uci set system.led_wlan5g.mode='link tx rx'    
    uci commit
    /usr/bin/uci2dat -d radio1 -f /etc/Wireless/iNIC/iNIC_ap.dat > /dev/null
    LOWERMAC=$(echo $CLIENT_MAC | awk '{ print tolower($1) }')
    insmod /lib/modules/`uname -r`/mt7610e.ko mac=$LOWERMAC
    echo "mt7610e mac=$LOWERMAC" >> /etc/modules.d/51-mt7610e
    cp /sbin/mtkwifi /sbin/wifi    
  fi

  /sbin/wifi up
  log "FIRSTBOOT" "Wireless set successfully"

  # Configure DHCP
  A=$(uci get dhcp.@dnsmasq[0].interface)
  if [ "$A" ] 
  then
    uci delete dhcp.@dnsmasq[0].interface
  fi
  uci add_list dhcp.@dnsmasq[0].interface='lan'
  uci set dhcp.lan.leasetime="1h"
  uci commit dhcp

  # Configure LAN
  uci set network.lan.ipaddr="10.0.10.1"
  uci set network.lan.netmask="255.255.255.0"
  uci commit network
  A=$(grep "10.0.10.1 anlixrouter" /etc/hosts)
  if [ ! "$A" ] 
  then
    echo "10.0.10.1 anlixrouter" >> /etc/hosts
  fi
  /sbin/ifup lan
  log "FIRSTBOOT" "LAN Configured successfully"

  # Configure WAN
  wan_proto_value=$(uci get network.wan.proto)
  custom_connection_type=$(cat /root/custom_connection_type || echo "")
  uci set network.wan.proto="$FLM_WAN_PROTO"
  uci set network.wan.mtu="$FLM_WAN_MTU"
  if [ "$FLM_WAN_PROTO" = "pppoe" ] && [ "$wan_proto_value" != "pppoe" ] && [ "$custom_connection_type" != "dhcp" ]
  then
    uci set network.wan.username="$FLM_WAN_PPPOE_USER"
    uci set network.wan.password="$FLM_WAN_PPPOE_PASSWD"
    uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
  fi
  # Check custom wan type for pppoe
  if [ "$custom_connection_type" = "pppoe" ]
  then
    uci set network.wan.proto="$custom_connection_type"
    uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
  fi
  # Check for custom pppoe credentials
  if [ "$custom_connection_type" = "pppoe" ] && [ -f  /root/custom_pppoe_user ] && [ -f  /root/custom_pppoe_password ]
  then
    _custom_pppoe_user=$(cat /root/custom_pppoe_user)
    _custom_pppoe_password=$(cat /root/custom_pppoe_password)
    uci set network.wan.username="$_custom_pppoe_user"
    uci set network.wan.password="$_custom_pppoe_password"
  fi
  uci commit network
  /etc/init.d/network restart
  /etc/init.d/firewall restart
  /etc/init.d/dnsmasq restart
  log "FIRSTBOOT" "WAN Configured successfully"

  # Set root password
  PASSWORD_ENTRY=""
  (
    echo "$CLIENT_MAC" | awk -F ":" '{ print $1$2$3$4$5$6 }'
    sleep 1
    echo "$CLIENT_MAC" | awk -F ":" '{ print $1$2$3$4$5$6 }'
  )|passwd root

  # Configure Zabbix
  sed -i "s%ZABBIX-SERVER-ADDR%$ZBX_SVADDR%" /etc/zabbix_agentd.conf
  if [ "$ZBX_SEND_DATA" == "y" ]
  then
    # Enable Zabbix
    /etc/init.d/zabbix_agentd enable
    /etc/init.d/zabbix_agentd start
    log "FIRSTBOOT" "Zabbix Enabled"
  else
    # Disable Zabbix
    /etc/init.d/zabbix_agentd stop
    /etc/init.d/zabbix_agentd disable
  fi

  #Configure uhttpd to use anlix scripts
  uci delete uhttpd.main.listen_http
  uci delete uhttpd.main.listen_https
  uci add_list uhttpd.main.listen_https='anlixrouter:443'
  uci set uhttpd.defaults.location='ANLIX'
  uci set uhttpd.defaults.commonname='anlixrouter'
  uci set uhttpd.defaults.state='rj'
  uci set uhttpd.defaults.country='BR'
  uci set uhttpd.main.no_dirlists='1'
  uci set uhttpd.main.lua_prefix='/anlix'
  uci set uhttpd.main.lua_handler='/usr/share/anlix/index.lua'
  uci commit uhttpd

  log "FIRSTBOOT" "First boot completed"
  echo "0" > /tmp/clean_boot
}

[ -f "/etc/firstboot" ] || {
  firstboot
}

echo "0" > /etc/firstboot
