#!/bin/sh

uci delete uhttpd.main.listen_http
uci delete uhttpd.main.listen_https
uci add_list uhttpd.main.listen_https='anlixrouter:443'
uci set uhttpd.defaults.location='ANLIX'
uci set uhttpd.defaults.commonname='anlixrouter'
uci set uhttpd.defaults.state='rj'
uci set uhttpd.defaults.country='BR'
uci set uhttpd.main.no_dirlists='1'
uci set uhttpd.main.lua_prefix='/anlix'
uci set uhttpd.main.lua_handler='/usr/share/anlix/index.lua'

uci commit uhttpd

exit 0
