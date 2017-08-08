#!/bin/sh

. /usr/share/flashman_init.conf

# Verify if connection is up.
check_connectivity()
{
  if ping -q -c 2 -W 2 $FLM_SVADDR  >/dev/null
  then
    # true
    echo 0
  else
    # false
    echo 1
  fi
}

connected=false
while [ "$connected" != true ]
do
  if [ "$(check_connectivity)" -eq 0 ]
  then
	  sh /usr/share/flashman_update.sh now
    connected=true
  fi
  sleep 5
done

while true
do
	sh /usr/share/flashman_update.sh
  sleep 300
done
