#!/bin/sh
# Copyright (C) 2006-2011 OpenWrt.org

if ( ! grep -qsE '^root:[!x]?:' /etc/shadow || \
     ! grep -qsE '^root:[!x]?:' /etc/passwd ) && \
   [ -z "$FAILSAFE" ]
then
	echo "Login failed."
	exit 0
else
	busybox login
	exit 0
fi

exec /bin/ash --login
