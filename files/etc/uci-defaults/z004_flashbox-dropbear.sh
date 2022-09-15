#!/bin/sh
. /usr/share/libubox/jshn.sh

# Get if ipv6 is enable
json_cleanup
json_load_file /root/flashbox_config.json
json_get_var _enable_ipv6 enable_ipv6
json_get_var _wan_conn_type wan_conn_type
json_close_object

[ "$(uci -q get dropbear.@dropbear[0])" != 'dropbear' ] && \
uci add dropbear dropbear

uci set dropbear.@dropbear[0]=dropbear
uci set dropbear.@dropbear[0].PasswordAuth=off
uci set dropbear.@dropbear[0].RootPasswordAuth=off
uci set dropbear.@dropbear[0].Port=36022
uci set dropbear.@dropbear[0].Interface=wan

[ "$(uci -q get dropbear.@dropbear[1])" != 'dropbear' ] && \
uci add dropbear dropbear

uci set dropbear.@dropbear[1]=dropbear
uci set dropbear.@dropbear[1].PasswordAuth=off
uci set dropbear.@dropbear[1].RootPasswordAuth=off
uci set dropbear.@dropbear[1].Port=36022

uci set dropbear.@dropbear[1].Interface=$([ "$_wan_conn_type" = "pppoe" ] && echo 'wan_6' || echo 'wan6')

# Only enable this ssh configuration if ipv6 is enabled
uci set dropbear.@dropbear[1].enable=$_enable_ipv6

[ "$(uci -q get dropbear.@dropbear[2])" != 'dropbear' ] && \
uci add dropbear dropbear

uci set dropbear.@dropbear[2]=dropbear
uci set dropbear.@dropbear[2].PasswordAuth=off
uci set dropbear.@dropbear[2].RootPasswordAuth=off
uci set dropbear.@dropbear[2].Port=36022
uci set dropbear.@dropbear[2].Interface=lan

uci commit dropbear

exit 0
