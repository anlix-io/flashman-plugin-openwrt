#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
}
