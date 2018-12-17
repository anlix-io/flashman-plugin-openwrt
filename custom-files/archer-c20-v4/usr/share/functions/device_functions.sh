#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
  /usr/bin/uci2dat -d radio0 -f /etc/wireless/mt7628/mt7628.dat > /dev/null
  /usr/bin/uci2dat -d radio1 -f /etc/Wireless/iNIC/iNIC_ap.dat > /dev/null
}
