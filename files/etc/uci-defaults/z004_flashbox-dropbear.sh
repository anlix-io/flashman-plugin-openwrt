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
uci set dropbear.@dropbear[1].Interface=lan

uci commit dropbear

exit 0
