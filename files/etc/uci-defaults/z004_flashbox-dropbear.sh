#!/bin/sh

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
uci set dropbear.@dropbear[1].Interface=wan6
uci set dropbear.@dropbear[1].enable=0

[ "$(uci -q get dropbear.@dropbear[2])" != 'dropbear' ] && \
uci add dropbear dropbear

uci set dropbear.@dropbear[2]=dropbear
uci set dropbear.@dropbear[2].PasswordAuth=off
uci set dropbear.@dropbear[2].RootPasswordAuth=off
uci set dropbear.@dropbear[2].Port=36022
uci set dropbear.@dropbear[2].Interface=lan

uci commit dropbear

exit 0
