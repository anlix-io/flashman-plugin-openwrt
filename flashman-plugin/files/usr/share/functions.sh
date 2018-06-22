#!/bin/sh

. /usr/share/flashman_init.conf
. /lib/functions/network.sh
. /usr/share/libubox/jshn.sh

log() {
  logger -t "$1 " "$2"
}

# Verify if connection is up.
check_connectivity_flashman()
{
  if ping -q -c 2 -W 2 "$FLM_SVADDR"  >/dev/null
  then
    # true
    echo 0
  else
    # false
    echo 1
  fi
}

check_connectivity_internet()
{
  if ping -q -c 2 -W 2 www.google.com  >/dev/null
  then
    # true
    echo 0
  else
    # false
    echo 1
  fi
}

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

send_boot_log()
{
  if [ "$1" == "boot" ]
  then
    if [ -e /tmp/clean_boot ]
    then
      header="X-ANLIX-LOGS: FIRST"
    else
      header="X-ANLIX-LOGS: BOOT"
    fi
  fi

  if [ "$1" == "live" ]
  then
    header="X-ANLIX-LOGS: LIVE"
  fi

  CLIENT_MAC=$(get_mac)

  _res=$(logread | gzip | curl -s --tlsv1.2 --connect-timeout 5 --retry 1 -H "Content-Type: application/octet-stream" \
  -H "X-ANLIX-ID: $CLIENT_MAC" -H "$header"  --data-binary @- "https://$FLM_AUTH_SVADDR/deviceinfo/logs")

  json_load "$_res"
  json_get_var _processed processed
  json_close_object

  return $_processed
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

set_mqtt_secret()
{
  CLIENT_MAC=$(get_mac)
  if [ -e "/root/mqtt_secret" ]
  then
    cat /root/mqtt_secret
  else
    MQTTSEC=$(cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c${1:-32})
    _res=$(curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
           --tlsv1.2 --connect-timeout 5 --retry 1 \
           --data "id=$CLIENT_MAC&organization=$FLM_CLIENT_ORG&secret=$FLM_CLIENT_SECRET&mqttsecret=$MQTTSEC" \
           "https://$FLM_SVADDR/deviceinfo/mqtt/add")

    json_load "$_res"
    json_get_var _is_registered is_registered
    json_close_object

    if [ "$_is_registered" = "1" ]                                                                       
    then                                                                                                 
      echo $MQTTSEC > /root/mqtt_secret
      cat /root/mqtt_secret                                                                                     
    fi
  fi  
}

reset_mqtt_secret()
{
  if [ -e "/root/mqtt_secret" ]
  then
    rm /root/mqtt_secret
  fi
  set_mqtt_secret
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
