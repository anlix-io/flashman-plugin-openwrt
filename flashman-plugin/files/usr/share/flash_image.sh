#!/bin/sh

. /usr/share/functions.sh

is_itf_traff_ok()
{
  local _threshold_in_bytes=8000
  local _traff_direction=$1
  local _default_gateway=$(cat /proc/net/route | awk 'NR==2 {print $1}')

  local _itf_direction_bytes_before=$(grep -F $_default_gateway /proc/net/dev | awk -F ":" '{print $2}' | awk '{print '$_traff_direction'}')
  sleep 1
  local _itf_direction_bytes_after=$(grep -F $_default_gateway /proc/net/dev | awk -F ":" '{print $2}' | awk '{print '$_traff_direction'}')
  local _traff_delta=`expr $_itf_direction_bytes_after - $_itf_direction_bytes_before`
  if [ $_traff_delta -ge $_threshold_in_bytes ]
  then
    echo "Traffic above threshold"
    return 1
  fi
  return 0
}

verify_probe_load()
{
  # Downstream, upstream traff columns
  local _down=\$1
  local _up=\$9
  if ! is_itf_traff_ok $_down
  then
    return 1
  fi
  if ! is_itf_traff_ok $_up
  then
    return 1
  fi
  return 0
}

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
    local _vendor=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $3 }')
    local _model=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $4 }' | sed 's/\//-/g')

    if ! download_file "https://$_sv_address/images/" $_vendor"_"$_model"_"$_release_id".bin" "/tmp"
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
    local _vendor=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $3 }')
    local _model=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $4 }' | sed 's/\//-/g')

    if verify_probe_load
    then
      clean_memory
      if get_image $_sv_address $_release_id
      then
        tar -zcf wireless.tar.gz /etc/config/wireless
        if sysupgrade -T wireless.tar.gz "/tmp/"$_vendor"_"$_model"_"$_release_id".bin"
        then
          curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
               -k --connect-timeout 5 --retry 0 \
               --data "id=$CLIENT_MAC" \
               "https://$SERVER_ADDR/deviceinfo/ack/"
          sysupgrade -f wireless.tar.gz "/tmp/"$_vendor"_"$_model"_"$_release_id".bin"
        else
          echo "Image check failed"
          return 1
        fi
      fi
    fi
  else
    echo "Error in number of args"
    return 1
  fi
}
