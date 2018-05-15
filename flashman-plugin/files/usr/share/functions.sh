#!/bin/sh

. /usr/share/flashman_init.conf
. /lib/functions/network.sh
. /usr/share/libubox/jshn.sh

download_file()
{
  dfile="$2"
  uri="$1/$dfile"
  dest_dir="$3"

  if [ "$#" -eq 3 ]
  then
    mkdir -p "$dest_dir"

    if test -e "$dest_dir/$dfile"
    then
      zflag="-z $dest_dir/$dfile"
    else
      zflag=
    fi

    curl_code=`curl -s -w "%{http_code}" -u routersync:landufrj123 \
              --tlsv1.2 --connect-timeout 5 --retry 3 \
              -o "/tmp/$dfile" $zflag "$uri"`

    if [ "$curl_code" = "200" ]
    then
      mv "/tmp/$dfile" "$dest_dir/$dfile"
      echo "Download file on $uri"
      return 0
    else
      echo "File not downloaded on $uri"
      if [ "$curl_code" != "304" ]
      then
        rm "/tmp/$dfile"
        return 1
      else
        return 0
      fi
    fi
  else
    echo "Wrong number of arguments"
    return 1
  fi
}

get_hardware_model()
{
  local _hardware_model=$(cat /tmp/sysinfo/model | awk '{ print toupper($2) }')
  echo "$_hardware_model" 
}

get_system_model()
{
  local _system_model=$(grep "system type" /proc/cpuinfo | awk '{ print toupper($5) }')
  echo "$_system_model"
}

get_mac()
{
  local _mac_address_tag=""
  local _system_model=$(get_system_model)
  local _hardware_model=$(get_hardware_model)

  if [ "$_system_model" = "MT7628AN" ]
  then
    if [ ! -z "$(awk '{ print toupper($1) }' /sys/class/net/eth0/address)" ]
    then
      _mac_address_tag=$(awk '{ print toupper($1) }' /sys/class/net/eth0/address)
    fi
  else
    if [ ! -d "/sys/class/ieee80211/phy1" ] || [ "$_hardware_model" = "TL-WDR3500" ]
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
  fi
  echo "$_mac_address_tag"
}

get_wan_ip()
{
  local _ip=""
  network_get_ipaddr _ip wan
  echo "$_ip"
}

is_authenticated()
{
  _is_authenticated=1

  if [ "$FLM_USE_AUTH_SVADDR" == "y" ]
  then
    CLIENT_MAC=$(get_mac)

    _res=$(curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
           --tlsv1.2 --connect-timeout 5 --retry 1 \
           --data "id=$CLIENT_MAC&organization=$FLM_CLIENT_ORG&secret=$FLM_CLIENT_SECRET" \
           "https://$FLM_AUTH_SVADDR/api/device/auth")

    json_load "$_res"
    json_get_var _is_authenticated is_authenticated
    json_close_object
  else
    _is_authenticated=0
  fi

  return $_is_authenticated
}
