#!/bin/sh

. /lib/functions/network.sh

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

get_wan_ip()
{
  local _ip=""
  network_get_ipaddr _ip wan
  echo "$_ip"
}
