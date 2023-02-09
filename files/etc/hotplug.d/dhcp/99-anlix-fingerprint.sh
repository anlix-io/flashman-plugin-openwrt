#!/bin/sh

if [ "$ACTION" = add ]
then
  if [ -n "$DNSMASQ_REQUESTED_OPTIONS" ] && [ -n "$MACADDR" ]
  then
    if [ ! -e /tmp/dhcpinfo ]
    then
      mkdir /tmp/dhcpinfo
    fi
    VENDOR=$(echo $DNSMASQ_VENDOR_CLASS | tr '()!@$#%^ ' '.')
    echo "$DNSMASQ_REQUESTED_OPTIONS $VENDOR" > /tmp/dhcpinfo/$MACADDR
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
