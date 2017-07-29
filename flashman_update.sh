#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/flash_image.sh

SERVER_ADDR="flashman.gss.mooo.com"
OPENWRT_VER=$(cat /etc/openwrt_version)
HARDWARE_MODEL=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $4 }')
NUMBER=$(head /dev/urandom | tr -dc "012345" | head -c1)

get_mac()
{
  local _mac_address_tag=""
  if [ ! -d "/sys/class/ieee80211/phy1" ] || [ "$HARDWARE_MODEL" = "TL-WDR3500" ]
  then
    if [ ! -z "$(awk '{ print toupper($1) }' /sys/class/ieee80211/phy0/macaddress)" ]
    then
      _mac_address_tag=$(awk '{ print toupper($1) }' /sys/class/ieee80211/phy0/macaddress)
    fi
  else
    if [ ! -z "$(awk '{ print toupper($1) }' /sys/class/ieee80211/phy1/macaddress)" ]
    then
      _mac_address_tag=$(awk '{ print toupper($1) }' /sys/class/ieee80211/phy1/macaddress)
    fi
  fi
  echo "$_mac_address_tag"
}

CLIENT_MAC=$(get_mac)

if [ "$NUMBER" -eq 3 ] || [ "$1" == "now" ]
then
  local _res=$(curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
               -k --connect-timeout 5 --retry 0 \
               --data "id=$CLIENT_MAC&version=$OPENWRT_VER&model=$HARDWARE_MODEL" \
               "http://$SERVER_ADDR/deviceinfo/")

  json_load "$_res"
  json_get_var _do_update do_update
  json_get_var _release_number release_number
  if [ "$_do_update" == "1" ]
  then
    # Execute firmware update
    # TODO Don't forget to disablethe flash on FlashMan!
    run_reflash $SERVER_ADDR $_release_number
  fi
fi
