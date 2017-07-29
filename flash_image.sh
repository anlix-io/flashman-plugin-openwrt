#!/bin/ash

# Download files command
call_curl()
{
    dfile="$2"
    uri="$1/$dfile"
    dest_dir="$3"

    if [ "$#" -eq 3 ]
    then
        check_dir_or_create "$dest_dir"

        if test -e "$dest_dir/$dfile"
        then
            zflag="-z $dest_dir/$dfile"
        else
            zflag=
        fi

        curl_code=`curl -s -k -w "%{http_code}" -u routersync:landufrj123 \
                  --connect-timeout 5 --retry 3 \
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
    local _release_number=$2
    local _vendor=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $3 }')
    local _model=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $4 }' | sed 's/\//-/g')

    ret_value=$(call_curl "https://$_sv_address/images/" "$_vendor-$_model-$_release_number.bin" "/tmp")
    if ! "$ret_value"
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
    local _release_number=$2
    local _vendor=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $3 }')
    local _model=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $4 }' | sed 's/\//-/g')

    if verify_probe_load
    then
      clean_memory
      if get_image $_sv_address $_release_number
      then
        tar -zcf wireless.tar.gz /etc/config/wireless
        if sysupgrade -T wireless.tar.gz "/tmp/$_vendor-$_model-$_release_number.bin"
        then
          sysupgrade -f wireless.tar.gz "/tmp/$_vendor-$_model-$_release_number.bin"
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
