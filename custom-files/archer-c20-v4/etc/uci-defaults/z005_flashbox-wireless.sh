#!/bin/sh

#
# WARNING! This file might be a symbolic link! Check your sources!
#

. /usr/share/flashman_init.conf
. /usr/share/functions/device_functions.sh

MAC_LAST_CHARS=$(get_mac | awk -F: '{ print $5$6 }')
SSID_VALUE=$(uci -q get wireless.@wifi-iface[0].ssid)
ENCRYPTION_VALUE=$(uci -q get wireless.@wifi-iface[0].encryption)
LOWERMAC=$(get_mac | awk '{ print tolower($1) }')

# Wireless password cannot be empty or have less than 8 chars
if [ "$FLM_PASSWD" == "" ] || [ $(echo "$FLM_PASSWD" | wc -m) -lt 9 ]
then
  FLM_PASSWD=$(get_mac | sed -e "s/://g")
fi

# Configure WiFi default SSID and password
if { [ "$SSID_VALUE" = "OpenWrt" ] || [ "$SSID_VALUE" = "LEDE" ] || \
     [ "$SSID_VALUE" = "" ]; } && [ "$ENCRYPTION_VALUE" != "psk2" ]
then
  if [ "$FLM_SSID_SUFFIX" == "none" ]
  then
    #none
    setssid="$FLM_SSID"
  else
    #lastmac
    setssid="$FLM_SSID$MAC_LAST_CHARS"
  fi
  touch /etc/config/wireless

  uci set wireless.radio0=wifi-device
  # Disable the interface!
  # MT7628 use a dat file, we only get the parameters from here
  uci set wireless.@wifi-device[0].disabled="1"
  uci set wireless.@wifi-device[0].type="ralink"
  uci set wireless.@wifi-device[0].txpower="100"
  uci set wireless.@wifi-device[0].variant="mt7628"
  uci set wireless.@wifi-device[0].channel="$FLM_24_CHANNEL"
  uci set wireless.@wifi-device[0].hwmode="11n"
  uci set wireless.@wifi-device[0].country="BR"
  uci set wireless.@wifi-device[0].htmode="HT40"
  uci set wireless.default_radio0=wifi-iface
  uci set wireless.@wifi-iface[0].ifname="ra0"
  uci set wireless.@wifi-iface[0].mode="ap"
  uci set wireless.@wifi-iface[0].network="lan"
  uci set wireless.@wifi-iface[0].device="radio0"
  uci set wireless.@wifi-iface[0].ssid="$setssid"
  uci set wireless.@wifi-iface[0].encryption="psk2"
  uci set wireless.@wifi-iface[0].key="$FLM_PASSWD"
  # 5GHz - MT7610e
  uci set wireless.radio1=wifi-device
  # Disable the interface!
  # MT7610e use a dat file, we only get the parameters from here
  uci set wireless.@wifi-device[1].disabled="1"
  uci set wireless.@wifi-device[1].type="ralink"
  uci set wireless.@wifi-device[1].txpower="100"
  uci set wireless.@wifi-device[1].variant="mt7610e"
  uci set wireless.default_radio1=wifi-iface
  uci set wireless.@wifi-iface[1].ifname="rai0"
  uci set wireless.@wifi-iface[1].mode="ap"
  uci set wireless.@wifi-iface[1].network="lan"
  uci set wireless.@wifi-iface[1].device="radio1"

  uci commit wireless
fi

/usr/bin/uci2dat -d radio0 -f /etc/wireless/mt7628/mt7628.dat > /dev/null
insmod /lib/modules/`uname -r`/mt7628.ko mac=$LOWERMAC
echo "mt7628 mac=$LOWERMAC" >> /etc/modules.d/50-mt7628
# 5 GHz
/usr/bin/uci2dat -d radio1 -f /etc/Wireless/iNIC/iNIC_ap.dat > /dev/null
insmod /lib/modules/`uname -r`/mt7610e.ko mac=$LOWERMAC
echo "mt7610e mac=$LOWERMAC" >> /etc/modules.d/51-mt7610e

[ -e /sbin/wifi ] && mv /sbin/wifi /sbin/wifi_legacy
cp /sbin/mtkwifi /sbin/wifi

exit 0
