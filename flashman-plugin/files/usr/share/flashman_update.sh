#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/flash_image.sh
. /usr/share/functions.sh
. /usr/share/boot_setup.sh

SERVER_ADDR="flashman.gss.mooo.com"
OPENWRT_VER=$(cat /etc/openwrt_version)
HARDWARE_MODEL=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $4 }' | sed 's/\//-/g')
NUMBER=$(head /dev/urandom | tr -dc "012345" | head -c1)
CLIENT_MAC=$(get_mac)

if [ "$NUMBER" -eq 3 ] || [ "$1" == "now" ]
then
  # Sync date and time with GMT-3
	ntpd -n -q -p a.st1.ntp.br -p b.st1.ntp.br -p c.st1.ntp.br -p d.st1.ntp.br

  local _res=$(curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
               -k --connect-timeout 5 --retry 0 \
               --data "id=$CLIENT_MAC&version=$OPENWRT_VER&model=$HARDWARE_MODEL&release_id=$RELEASE_ID" \
               "https://$SERVER_ADDR/deviceinfo/syn/")

  json_load "$_res"
  json_get_var _do_update do_update
  json_get_var _release_id release_id
  if [ "$_do_update" == "1" ]
  then
    # Execute firmware update
    run_reflash $SERVER_ADDR $_release_id
  fi
fi
