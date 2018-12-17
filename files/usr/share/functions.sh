#!/bin/sh

. /usr/share/flashman_init.conf
. /lib/functions/network.sh
. /usr/share/libubox/jshn.sh

ANLIX_PKG_VERSION=$(cat /etc/anlix_version)
export ANLIX_PKG_VERSION

log() {
  logger -t "$1 " "$2"
}

#Verify ntp
ntp_anlix()
{
  if [ -f /tmp/anlixntp ]
  then
    cat /tmp/anlixntp
  else
    echo "unsync"
  fi
} 

resync_ntp()
{
  CLIENT_MAC=$(get_mac)
  _ntpinfo=$(ntp_anlix)
  _curdate=$(date +%s)
  _data="id=$CLIENT_MAC&ntp=$_ntpinfo&date=$_curdate"                  
  _url="https://$FLM_SVADDR/deviceinfo/ntp" 

  #date sync with flashman is done insecure
  _res=$(curl -k -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
   --tlsv1.2 --connect-timeout 5 --retry 1 --data "$_data" "$_url")

  if [ "$?" -eq 0 ]                                                          
  then
    json_load "$_res"
    json_get_var _need_update need_update
    json_get_var _new_date new_date
    json_close_object

    if [ $_need_update = "1" ]
    then
      log "NTP_FLASHMAN" "Change date to $_new_date"                                                                       
      date +%s -s "@$_new_date"
      echo "flash_sync" > /tmp/anlixntp                                                               
    else
      log "NTP_FLASHMAN" "No need to change date (Server clock $_new_date)"
      echo "flash_sync" > /tmp/anlixntp
    fi                                                                 
  else                                                           
    log "NTP_FLASHMAN" "Error in CURL: $?"     
  fi  
}

#send data to flashman using rest api
rest_flashman()
{
  _url=$1
  _data=$2

  _res=$(curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
     --tlsv1.2 --connect-timeout 5 --retry 1 --data "$_data&secret=$FLM_CLIENT_SECRET" "https://$FLM_SVADDR/$_url")

  _curl_out=$?

  if [ "$_curl_out" -eq 0 ]
  then
    echo "$_res"
    return 0
  elif [ "$_curl_out" -eq 51 ]
  then
    # curl code 51 is bad certificate
    return 2
  else
    # other curl errors
    return 1
  fi
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
  -H "X-ANLIX-ID: $CLIENT_MAC" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" -H "$header"  --data-binary @- "https://$FLM_SVADDR/deviceinfo/logs")

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
  elif  [ "$_hardware_model" = "DIR-819" ]                                             
  then                                                                                 
    if [ ! -z "$(awk '{ print toupper($1) }' /sys/class/net/eth0.1/address)" ]         
    then                                                                               
      _mac_address_tag=$(awk '{ print toupper($1) }' /sys/class/net/eth0.1/address)    
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
    _rand=$(head /dev/urandom | tr -dc A-Z-a-z-0-9)
    MQTTSEC=${_rand:0:32}
    _data="id=$CLIENT_MAC&mqttsecret=$MQTTSEC"
    _url="deviceinfo/mqtt/add"
    _res=$(rest_flashman "$_url" "$_data") 

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

json_update_index() {
  _index=$1
  _json_var=$2

  json_init
  [ -f /etc/anlix_indexes ] && json_load "$(cat /etc/anlix_indexes)"
  json_add_string "$_json_var" "$_index"
  json_close_object
  json_dump | sed "s/\"/\'/g" > /etc/anlix_indexes
}

json_get_index() {
  _index=$1
  _idx_val=""

  if [ -f /etc/anlix_indexes ]
  then
    json_load "$(cat /etc/anlix_indexes)"
    json_get_var _idx_val "$_index"
    json_close_object
  fi
  echo "$_idx_val"
}

add_static_ip() {
  _mac=$1
  _dmz=$2

  A=$(grep "$_mac" /tmp/dhcp.leases | awk '{print $3}')

  #Device is online: use the same ip address
  if [ "$A" ] && [ "$_dmz" = "1" ] && [ "${A:0:10}" = "192.168.43" ] 
  then
    echo "$_mac $A" >> /etc/ethers
    echo "$A"
    return
  fi

  if [ "$A" ] && [ "$_dmz" = "0" ] && [ "${A:0:7}" = "10.0.10" ] 
  then
    echo "$_mac $A" >> /etc/ethers
    echo "$A"
    return
  fi

  #Device is offline, choose an ip address 
  if [ "$_dmz" = "1" ] 
  then
    [ -f /etc/ethers ] && NXDMZ=$(grep 192.168.43 /etc/ethers | awk '{print substr($2,length($2)-2,3)}' | tail -1) 
    [ ! "$NXDMZ" ] && NXDMZ="130" || NXDMZ=$((NXDMZ+1))
    echo "$_mac 192.168.43.$NXDMZ" >> /etc/ethers
    echo "192.168.43.$NXDMZ"
  else
    [ -f /etc/ethers ] && NXDMZ=$(grep 10.0.10 /etc/ethers | awk '{print substr($2,length($2)-1,2)}' | tail -1) 
    [ ! "$NXDMZ" ] && NXDMZ="50" || NXDMZ=$((NXDMZ+1))
    echo "$_mac 10.0.10.$NXDMZ" >> /etc/ethers
    echo "10.0.10.$NXDMZ"            
  fi
}

update_port_forward() {
  CLIENT_MAC=$(get_mac)
  log "PORT FORWARD" "Requesting Flashman ..."
  _data="id=$CLIENT_MAC"
  _url="deviceinfo/get/portforward/"
  _res=$(rest_flashman "$_url" "$_data") 

  _retstatus=$?
  if [ $_retstatus -eq 0 ]
  then
    json_load "$_res"
    json_get_var _FLASHIDX forward_index

    [ -f /etc/ethers ] && rm /etc/ethers

    #remove old forward rules
    A=$(uci -X show firewall | grep ".name='anlix_forward_.*'") 
    for i in $A 
    do 
      B=$(echo "$i"|awk -F '.' '{ print "firewall."$2}')
      uci delete "$B"
    done

    json_select forward_rules
    INDEX="1" 
    IDX=1
    while json_get_type TYPE $INDEX && [ "$TYPE" = object ]; do
      json_select "$((INDEX++))"
      json_get_var _mac mac
      json_get_var _dmz dmz
      IP=$(add_static_ip "$_mac" "$_dmz")

      json_select port
      PORTIDX=1
      while json_get_type TYPEPORT $PORTIDX && [ "$TYPEPORT" = int ]; do
        json_get_var _port "$((PORTIDX++))"
        uci add firewall redirect
        uci set firewall.@redirect[-1].src='wan'
        uci set firewall.@redirect[-1].src_dport="$_port" 
        uci set firewall.@redirect[-1].proto='tcpudp'
        if [ "$_dmz" = 1 ]
        then
          uci set firewall.@redirect[-1].dest='dmz'
        else
          uci set firewall.@redirect[-1].dest='lan'
        fi
        uci set firewall.@redirect[-1].dest_ip="$IP"
        uci set firewall.@redirect[-1].target="DNAT"
        uci set firewall.@redirect[-1].name="anlix_forward_$((IDX++))"
      done
      json_select ".."
      json_select ".."
    done
    json_close_object
    uci commit firewall
    /etc/init.d/dnsmasq reload
    /etc/init.d/firewall reload 

    #Save index
    json_update_index "$_FLASHIDX" "forward_index"
  fi
}

get_online_devices() {
  MACSDHCP=$(awk '{ print $2 }' /tmp/dhcp.leases)
  IPSDHCP=$(awk '{ print $3 }' /tmp/dhcp.leases)
  NAMESDHCP=$(awk '{ if ($4=="*") print "!"; else print $4 }' /tmp/dhcp.leases) 

  json_init
  json_add_object "Devices"
  idx=1 
  for i in $MACSDHCP
  do
    json_add_object "$i"
    json_add_string "ip" "$(echo $IPSDHCP | awk -v N=$idx '{ print $N }')"  
    json_add_string "hostname" "$(echo $NAMESDHCP | awk -v N=$idx '{ print $N }')"
    idx=$((idx+1))
    json_close_object
  done
  json_close_object
  json_dump 
}

send_online_devices() {
  CLIENT_MAC=$(get_mac)

  _res=$(get_online_devices | curl -s --tlsv1.2 --connect-timeout 5 --retry 1 -H "Content-Type: application/json" \
  -H "X-ANLIX-ID: $CLIENT_MAC" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" --data @- "https://$FLM_SVADDR/deviceinfo/receive/devices")

  json_load "$_res"
  json_get_var _processed processed
  json_close_object

  return $_processed
}

check_zabbix_startup() {
  sed -i "s%ZABBIX-SERVER-ADDR%$ZBX_SVADDR%" /etc/zabbix_agentd.conf
  if [ "$ZBX_SEND_DATA" == "y" ]
  then
    # Enable Zabbix
    /etc/init.d/zabbix_agentd enable
    /etc/init.d/zabbix_agentd start
    log "ZABBIX" "Zabbix Enabled"
  else
    # Disable Zabbix
    /etc/init.d/zabbix_agentd stop
    /etc/init.d/zabbix_agentd disable
  fi
}
