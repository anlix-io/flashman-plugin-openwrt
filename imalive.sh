#!/bin/sh

# Verify if connection is up.
check_connectivity()
{
  if ping -q -c 2 -W 2 8.8.8.8  >/dev/null
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
	  sh ./flashman_update.sh now
    connected=true
  fi
  sleep 5
done
