#!/bin/sh

if [ ! -e /tmp/dhcpinfo ]
then
  mkdir /tmp/dhcpinfo
fi

if [ "$ACTION" = add ] && [ -n "$DNSMASQ_VENDOR_CLASS" ]
then
  if [ "${DNSMASQ_VENDOR_CLASS:0:5}" == "ANLIX" ]
  then
    . /usr/share/libubox/jshn.sh
    _mac="$(echo $DNSMASQ_SUPPLIED_HOSTNAME | sed 's/-/:/g')"
    json_cleanup
    json_init
    json_add_string mac "$_mac"
    [ "${DNSMASQ_VENDOR_CLASS#ANLIX}" == "02" ] && json_add_int status 0 || json_add_int status 1
    ubus call anlix_sapo notify_sapo "$(json_dump)"
    json_close_object
  fi
fi

if [ "$ACTION" = add ] || [ "$ACTION" = update ]
then
  if [ -n "$DNSMASQ_REQUESTED_OPTIONS" ] && [ -n "$MACADDR" ]
  then
    echo "$DNSMASQ_REQUESTED_OPTIONS $DNSMASQ_VENDOR_CLASS" > /tmp/dhcpinfo/$MACADDR
  fi
elif [ "$ACTION" = remove ]
then
  if [ -n "$MACADDR" ]
  then
    if [ -e /tmp/dhcpinfo/$MACADDR ]
    then
      rm /tmp/dhcpinfo/$MACADDR
    fi
  fi
fi
