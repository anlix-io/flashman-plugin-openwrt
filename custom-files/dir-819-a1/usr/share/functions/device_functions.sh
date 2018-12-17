#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
  /usr/bin/uci2dat -d radio0 -f /etc/Wireless/RT2860/RT2860AP.dat > /dev/null
  /usr/bin/uci2dat -d radio1 -f /etc/Wireless/iNIC/iNIC_ap.dat > /dev/null
}
