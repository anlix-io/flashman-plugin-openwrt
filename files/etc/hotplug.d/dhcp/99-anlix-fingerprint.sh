#!/bin/sh

if [ ! -e /tmp/dhcpinfo ]
then
  mkdir /tmp/dhcpinfo
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
