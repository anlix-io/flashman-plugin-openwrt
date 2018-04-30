#!/bin/sh

. /usr/share/functions.sh

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
    local _sv_address=$1
    local _release_id=$2
    local _vendor=$(cat /tmp/sysinfo/model | awk '{ print toupper($1) }')
    local _model=$(get_hardware_model)
    local _ver=$(cat /tmp/sysinfo/model | awk '{ print toupper($3) }')

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
    local _sv_address=$1
    local _release_id=$2
    local _vendor=$(cat /tmp/sysinfo/model | awk '{ print toupper($1) }')
    local _model=$(get_hardware_model)
    local _ver=$(cat /tmp/sysinfo/model | awk '{ print toupper($3) }')

    clean_memory
    if get_image $_sv_address $_release_id
    then
      tar -zcf /tmp/config.tar.gz /etc/config /root/router_passwd
      if sysupgrade -T "/tmp/"$_vendor"_"$_model"_"$_ver"_"$_release_id".bin"
      then
        curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
             -k --tlsv1.2 --connect-timeout 5 --retry 0 \
             --data "id=$CLIENT_MAC" \
             "https://$SERVER_ADDR/deviceinfo/ack/"
        sysupgrade -f /tmp/config.tar.gz "/tmp/"$_vendor"_"$_model"_"$_ver"_"$_release_id".bin"
      else
        echo "Image check failed"
        return 1
      fi
    fi
  else
    echo "Error in number of args"
    return 1
  fi
}
