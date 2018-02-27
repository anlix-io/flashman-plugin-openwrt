#!/bin/bash

OPENWRT_LEDE_DIR=$1

TARGET=$OPENWRT_LEDE_DIR"/package/base-files/files/etc/shadow"

#SHARED_KEY=$(cat key_file.txt)
SHARED_KEY=$(dd if=/dev/random count=16 bs=1 | xxd -ps)

PASSWD_ROOT_HASH=$(openssl passwd -1 -salt $(openssl rand -base64 6) $SHARED_KEY)

echo "root:$PASSWD_ROOT_HASH:0:0:99999:7:::" > ./shadow
tail --lines $(( $(wc -l "$TARGET" | awk '{print $1}')-1 )) "$TARGET" >> ./shadow

mv ./shadow "$TARGET"