#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions.sh
. /usr/share/functions/device_functions.sh

clean_memory()
{
  rm -r /tmp/opkg-lists/
  echo 3 > /proc/sys/vm/drop_caches
}

# Downloads correct image based on current model
get_image()
{
  if [ "$#" -eq 2 ]
  then
    _sv_address=$1
    _release_id=$2
    _vendor=$(cat /tmp/sysinfo/model | awk '{ print toupper($1) }')
    _model=$(get_hardware_model | awk -F "/" '{ if($2 != "") { print $1"D"; } else { print $1 } }')
    _ver=$(cat /tmp/sysinfo/model | awk '{ print toupper($3) }')

    if ! download_file "https://$_sv_address/firmwares" $_vendor"_"$_model"_"$_ver"_"$_release_id".bin" "/tmp"
    then
      echo "Image download failed"
      return 1
    fi
  else
    echo "Error in number of args"
    return 1
  fi
  return 0
}

run_reflash()
{
  if [ "$#" -eq 2 ]
  then
    echo "Init image reflash"
    _sv_address=$1
    _release_id=$2
    _vendor=$(cat /tmp/sysinfo/model | awk '{ print toupper($1) }')
    _model=$(get_hardware_model | awk -F "/" '{ if($2 != "") { print $1"D"; } else { print $1 } }')
    _ver=$(cat /tmp/sysinfo/model | awk '{ print toupper($3) }')

    clean_memory
    if get_image "$_sv_address" "$_release_id"
    then
      # Save pppoe user and pass if current conn type is pppoe
      local _wan_proto_value=$(uci get network.wan.proto)
      if [ "$_wan_proto_value" = "pppoe" ]
      then
        local _pppoe_user=$(uci get network.wan.username)
        local _pppoe_password=$(uci get network.wan.password)
        echo "$_pppoe_user" > /root/custom_pppoe_user
        echo "$_pppoe_password" > /root/custom_pppoe_password
      fi
      echo "$_release_id" > /root/upgrade_info
      tar -zcf /tmp/config.tar.gz /etc/config/wireless /root/router_passwd \
               /root/mqtt_secret /root/custom_connection_type /root/upgrade_info \
               /root/custom_pppoe_user /root/custom_pppoe_password
      rm -f /root/upgrade_info
      if sysupgrade -T "/tmp/"$_vendor"_"$_model"_"$_ver"_"$_release_id".bin"
      then
        curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
             --tlsv1.2 --connect-timeout 5 --retry 0 \
             --data "id=$(get_mac)&status=1" \
             "https://$_sv_address/deviceinfo/ack/"
        sysupgrade -f /tmp/config.tar.gz "/tmp/"$_vendor"_"$_model"_"$_ver"_"$_release_id".bin"
      else
        curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
           --tlsv1.2 --connect-timeout 5 --retry 0 \
           --data "id=$(get_mac)&status=0" \
           "https://$_sv_address/deviceinfo/ack/"
        echo "Image check failed"
        return 1
      fi
    else
      curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
        --tlsv1.2 --connect-timeout 5 --retry 0 \
        --data "id=$(get_mac)&status=2" \
        "https://$_sv_address/deviceinfo/ack/"
    fi
  else
    echo "Error in number of args"
    return 1
  fi
}
