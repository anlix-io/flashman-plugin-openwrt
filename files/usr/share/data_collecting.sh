#!/bin/sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/custom_wireless_driver.sh
. /usr/share/flashman_init.conf

dataCollectingDir="/tmp/data_collecting"
rawDataFile="${dataCollectingDir}/raw"
compressedDataDir="${dataCollectingDir}/compressed"
wanBytesFile="${dataCollectingDir}/wan_bytes"
wanPacketsFile="${dataCollectingDir}/wan_pkts"

collect_wan() {

	local isBurstLossActive=${activeMeasures/*bl*/bl}
	local isPingAndWanActive=${activeMeasures/*p&w*/p&w}

	[ "$isBurstLossActive" != "bl" ] && [ "$isPingAndWanActive" != "p&w" ] && return

	local sendThisRound=1

	local rxBytes=$(get_wan_bytes_statistics RX)
	local txBytes=$(get_wan_bytes_statistics TX)

	local last_rxBytes=""
	local last_txBytes=""

	if [ -f "$wanBytesFile" ]; then
		last_rxBytes=$(cat "$wanBytesFile")
		last_txBytes=${last_rxBytes##* }
		last_rxBytes=${last_rxBytes%% *}
	fi

	local rxBytesDiff=0
	local txBytesDiff=0

	if [ "$last_rxBytes" == "" ] || [ "$last_txBytes" == "" ]; then
		> "$wanBytesFile"
		echo "$rxBytes $txBytes" >> "$wanBytesFile"
		sendThisRound=0
	else
		rxBytesDiff=$(($rxBytes - $last_rxBytes))
		txBytesDiff=$(($txBytes - $last_txBytes))
		{ [ "$rxBytesDiff" -lt 0 ] || [ "$txBytesDiff" -lt 0 ]; } && sendThisRound=0
	fi

	> "$wanBytesFile"
	echo "$rxBytes $txBytes" >> "$wanBytesFile"

	if [ "$sendThisRound" -eq 1 ]; then
		local string="|wanBytes $rxBytesDiff $txBytesDiff"
		rawData="${rawData}${string}"
	else
		activeMeasures="${activeMeasures/bl /}"
		activeMeasures="${activeMeasures/ bl/}"
		activeMeasures="${activeMeasures/bl/}"
		activeMeasures="${activeMeasures/p&w /}"
		activeMeasures="${activeMeasures/ p&w/}"
		activeMeasures="${activeMeasures/p&w/}"
	fi

	if [ "$isPingAndWanActive" != "p&w" ]; then
		return
	fi

	local rxPackets=$(get_wan_packets_statistics RX)
	local txPackets=$(get_wan_packets_statistics TX)

	local last_rxPackets=""
	local last_txPackets=""

	if [ -f "$wanPacketsFile" ]; then
		last_rxPackets=$(cat "$wanPacketsFile")
		last_txPackets=${last_rxPackets##* }
		last_rxPackets=${last_rxPackets%% *}
	fi

	local rxPacketsDiff=0
	local txPacketsDiff=0

	if [ "$last_rxPackets" == "" ] || [ "$last_txPackets" == "" ]; then
		> "$wanPacketsFile"
		echo "$rxPackets $txPackets" >> "$wanPacketsFile"
		sendThisRound=0
	else
		rxPacketsDiff=$(($rxPackets - $last_rxPackets))
		txPacketsDiff=$(($txPackets - $last_txPackets))
		{ [ "$rxPacketsDiff" -lt 0 ] || [ "$txPacketsDiff" -lt 0 ]; } && sendThisRound=0
	fi

	> "$wanPacketsFile"
	echo "$rxPackets $txPackets" >> "$wanPacketsFile"

	if [ "$sendThisRound" -ne 1 ]; then
		activeMeasures="${activeMeasures/p&w /}"
		activeMeasures="${activeMeasures/ p&w/}"
		activeMeasures="${activeMeasures/p&w/}"
		return
	fi

	local string="|wanPkts $rxPacketsDiff $txPacketsDiff"
	rawData="${rawData}${string}"
}

collect_burst() {

	local isBurstLossActive=${activeMeasures/*bl*/bl}
	local isPingAndWanActive=${activeMeasures/*p&w*/p&w}

	[ "$isBurstLossActive" != "bl" ] && [ "$isPingAndWanActive" != "p&w" ] && return

	local pingResult=$(ping -i 0.01 -c "$pingPackets" "$pingServerAddress")
	local pingError="$?"

	if [ "$pingError" -eq 2 ]; then
		activeMeasures="${activeMeasures/bl /}"
		activeMeasures="${activeMeasures/ bl/}"
		activeMeasures="${activeMeasures/bl/}"
		activeMeasures="${activeMeasures/p&w /}"
		activeMeasures="${activeMeasures/ p&w/}"
		activeMeasures="${activeMeasures/p&w/}"
		return
	fi

	local pingResultAux=${pingResult##* ping statistics ---[$'\r\n']}
	local transmitted=${pingResultAux% packets transmitted*}
	local received=${pingResultAux% received*}
	received=${received##* }
	local loss=$(($transmitted - $received))

	local string="$loss $transmitted"

	local latencyStats=${pingResult#*/mdev = }

	# when there is 100% packet loss there the strings remain equal
	# we only want to collect latency and std when there isn't 100% loss
	# if loss is 100% we just send 0 in both cases, which will be ignored by the server
	if [ ${#latencyStats} == ${#pingResult} ]; then
	    string="$string 0 0"
	else
		local latencyAvg=${latencyStats#*/}
		latencyAvg=${latencyAvg%%/*}
		local latencyStd=${latencyStats##*/}
		latencyStd=${latencyStd%% *}

		string="$string $latencyAvg $latencyStd"
	fi

	if [ "$hasLatency" -eq 1 ]; then
		local latencies=$(printf "%s" "$pingResult" | head -n -4 | sed '1d' | (
		local pairs=""
		local firstLine=true
		while read line; do
			reached=${line%time=*}
			[ ${#reached} -lt ${#line} ] || continue

			pingNumber=${line#*icmp_*eq=}
			pingNumber=${pingNumber%% *}
			pingTime=${line#*time=}
			pingTime=${pingTime%% *}
			if [ "$firstLine" = true ]; then
				firstLine=false
			else
				pairs="${pairs},"
			fi
			pairs="${pairs}${pingNumber}=${pingTime}"
		done
		echo $pairs))
		[ ${#latencies} -gt 0 ] && string="${string} ${latencies}"
	fi
	
	rawData="${rawData}|burstPing $string"
}

collect_wifi_devices() {
	[ "$wifiDevices" -ne 1 ] && return

	local str=""

	local firstRawWrite=true

	for i in 0 1; do
		local wlan=$(get_root_ifname "$i" 2> /dev/null)
		[ "$wlan" == "" ] && continue
		local devices="$(iwinfo "$wlan" assoclist | grep ago)"
		local devices_rx_pkts="$(iwinfo "$wlan" assoclist | grep RX | grep -o '[0-9]\+ Pkts')"
		local devices_tx_pkts="$(iwinfo "$wlan" assoclist | grep TX | grep -o '[0-9]\+ Pkts')"

		local firstFileWrite=true

		local fileStr=""

		local lastPktsFile="${dataCollectingDir}/devices_24_pkts"
		if [[ "$i" -eq 1 ]]; then
			lastPktsFile="${dataCollectingDir}/devices_5_pkts"
		fi

		while [ ${#devices} -gt 0 ]; do

			local deviceMac=${devices%% *}

			local signal=${devices#*  }
			signal=${signal%% /*}
			[ "$signal" == "unknown" ] && devices=${devices#*$'\n'} && continue
			signal=${signal%% dBm*}

			devices=${devices#*\(SNR }

			local snr=${devices%%\)*}
			[ $signal -eq $snr ] && snr=$(($signal+95))

			local time=${devices%% ms*}
			time=${time##* }

			devices=${devices#*ago}
			devices=${devices#*$'\n'}

			[ "$time" -gt 60000 ] && continue
			
			local rx_pkts=${devices_rx_pkts%% *}
			devices_rx_pkts=${devices_rx_pkts#*$'\n'}

			local tx_pkts=${devices_tx_pkts%% *}
			devices_tx_pkts=${devices_tx_pkts#*$'\n'}

			[ "$rx_pkts" == "" ] && continue
			[ "$tx_pkts" == "" ] && continue

			[ "$firstFileWrite" == true ] && firstFileWrite=false || fileStr="$fileStr "
			fileStr="${fileStr}${deviceMac}_${rx_pkts}_${tx_pkts}"

			local rx_pkts_diff=""
			local tx_pkts_diff=""

			if [ -f "$lastPktsFile" ]; then
                local devices_pkts=$(cat "$lastPktsFile")

				local pkts_device_removed=${devices_pkts/"$deviceMac"/""}

				[ ${#pkts_device_removed} -ge ${#devices_pkts} ] && continue

				local last_pkts=${devices_pkts#*"$deviceMac"_}
				last_pkts=${last_pkts%% *}

				local last_rx_pkts=${last_pkts%_*}
				[ "$last_rx_pkts" == "" ] && continue
				rx_pkts_diff=$(($rx_pkts - $last_rx_pkts))
				
				local last_tx_pkts=${last_pkts#*_}
				[ "$last_tx_pkts" == "" ] && continue
				tx_pkts_diff=$(($tx_pkts - $last_tx_pkts))

				{ [ "$rx_pkts_diff" -lt 0 ] || [ "$tx_pkts_diff" -lt 0 ]; } && continue
			else
				continue
			fi

			[ "$firstRawWrite" == true ] && firstRawWrite=false || str="$str "
			str="${str}${i}_${deviceMac}_${signal}_${snr}_${rx_pkts_diff}_${tx_pkts_diff}"
		done
		> "$lastPktsFile"

		[ ${#fileStr} -gt 0 ] && echo "$fileStr" >> "$lastPktsFile"
	done
	if [ "$str" == "" ]; then
		activeMeasures="${activeMeasures/wd /}"
		activeMeasures="${activeMeasures/ wd/}"
		activeMeasures="${activeMeasures/wd/}"
	else
		rawData="${rawData}|wifiDevsStats ${str}"
	fi
}

fileSize() {
	local wcline=$(wc -c "$1")
	local size=${wcline% *}
	echo $size
}

sumFileSizesInPath() {
	local anyFile=false
	for i in "$1"/*; do
		[ -f "$i" ] || continue
		anyFile=true
		break
	done
	if [ "$anyFile" = false ]; then
		echo 0
		return 0
	fi

	local wcResult=$(wc -c "$1"/*)
	local hasTotal=${wcResult% total}

	if [ ${#hasTotal} -lt ${#wcResult} ]; then
		echo ${hasTotal##* }
	else
		echo ${wcResult%% *}
	fi
}

zipFile() {
	local capSize="$1"

	[ -f "$rawDataFile" ] || return 1 

	local size=$(fileSize "$rawDataFile")
	local dirSize=$(sumFileSizesInPath "$compressedDataDir")

	[ $(($size + $dirSize)) -lt $capSize ] && return 1

	gzip "$rawDataFile"
	mv "${rawDataFile}.gz" "$compressedDataDir/$(date +%s).gz"
}

removeOldFiles() {
	local capSize="$1"

	local dirSize=$(sumFileSizesInPath "$compressedDataDir")

	for i in "$compressedDataDir"/*; do
		[ $dirSize -lt $capSize ] && break;
		rm "$i"
		dirSize=$(($dirSize - $(fileSize "$i")))
	done
}

collectData() {
	local timestamp=$(date +%s)

	rawData=""

	activeMeasures=""

	local firstMeasurement=1

	if [ "$burstLoss" -eq 1 ]; then
		if [ "$firstMeasurement" -ne 1 ]; then
			activeMeasures="$activeMeasures "
		else
			firstMeasurement=0
		fi
		activeMeasures="${activeMeasures}bl"
	fi

	if [ "$pingAndWan" -eq 1 ]; then
		if [ "$firstMeasurement" -ne 1 ]; then
			activeMeasures="$activeMeasures "
		else
			firstMeasurement=0
		fi
		activeMeasures="${activeMeasures}p&w"
	fi

	if [ "$wifiDevices" -eq 1 ]; then
		if [ "$firstMeasurement" -ne 1 ]; then
			activeMeasures="$activeMeasures "
		else
			firstMeasurement=0
		fi
		activeMeasures="${activeMeasures}wd"
	fi

	collect_burst
	collect_wan
	collect_wifi_devices

	# mapping from measurement names to collected artifacts:
	# bl (burstLoss) -> burstPing, wanBytes
	# p&w (pingAndWan) -> burstPing, wanBytes, wanPkts
	# wd (wifiDevices) -> wifiDevsStats

	# example of an expected raw data with all measures present:
	# 'bl p&w wd|213234556456|burstPing 0 100 1.246 0.161|wanBytes 12345 1234|wanPkts 1234 123|wifiDevsStats 0_D0:9C:7A:EC:FF:FF_33_285_5136'
	[ -n "$rawData" ] && [ ${#activeMeasures} -gt 0 ] && echo "${activeMeasures}|${timestamp}${rawData}" >> "$rawDataFile";
	rawData=""

	mkdir -p "$compressedDataDir"
	# $(zipFile) returns 0 only if any amount of files has been compressed 
	# and, consequently, moved to the directory of compressed files. So
	# $(removeOldFiles) is only executed if any new compressed file was 
	# created.
	zipFile $((32*1024)) && removeOldFiles $((24*1024))
	# the difference between the cap size sent to $(zipFile) and 
	# $(removeOldFiles) is the size left as a minimum amount for raw data 
	# before compressing it. This means that, if there are no compressed files, 
	# the uncompressed file could grow to as much as the cap size given to 
	# $(zipFile). but in case there is any amount of compressed files, the 
	# uncompressed file can grow to as much as the cap size given to $(zipFile) 
	# minus the sum of all the compressed files sizes. As $(removeOldFiles) 
	# will keep the sum of all compressed files sizes to a maximum of its given 
	# cap size, the difference between these two cap sizes is the minimum size 
	# the uncompressed file will always have available for it's growth.
}

checkServerState() {
	local lastState="$1"
	if [ "$lastState" -ne "0" ]; then
		curl -s -m 10 "https://$alarmServerAddress:7890/ping" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" > /dev/null
		lastState="$?"
	fi
	return $lastState
}

sendToServer() {
	local filepath="$1"

	local mac=$(get_mac);

	status=$(curl --write-out '%{http_code}' -s -m 20 --connect-timeout 5 --output /dev/null \
	-XPOST "https://$alarmServerAddress:7890/data" -H 'Content-Encoding: gzip' \
	-H 'Content-Type: text/plain' -H "X-ANLIX-ID: $mac" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
	-H "Send-Time: $(date +%s)" --data-binary @"$filepath")
	curlCode="$?"

	[ "$curlCode" -ne 0 ] && log "DATA_COLLECTING" "Data sent with curl exit code '${curlCode}'." && return "$curlCode"
	log "DATA_COLLECTING" "Data sent with response status code '${status}'."
	[ "$status" -ge 200 ] && [ "$status" -lt 300 ] && return 0
	return 1
}

sendCompressedData() {
	for i in "$compressedDataDir"/*; do
		[ -f "$i" ] && { sendToServer "$i" || return "$?"; } && rm "$i"
	done
	return 0
}

sendUncompressedData() {
	[ -f "$rawDataFile" ] || return 0

	local compressedTempFile="${rawDataFile}.gz"
	[ -f "$compressedTempFile" ] && rm "$compressedTempFile"

	trap "rm $compressedTempFile" SIGTERM
	gzip -k "$rawDataFile"

	sendToServer "$compressedTempFile"
	local sentResult="$?"

	[ "$sentResult" -eq 0 ] && rm "$rawDataFile"
	rm "$compressedTempFile"
	trap - SIGTERM

	return $sentResult
}

sendData() {
	local tries=3

	while true; do
		local lastServerStateFilePath="$dataCollectingDir/serverState"
		local lastServerState="1"
		[ -f "$lastServerStateFilePath" ] && lastServerState=$(cat "$lastServerStateFilePath")

		checkServerState "$lastServerState" && sendCompressedData && sendUncompressedData
		local currentServerState="$?"

		[ "$currentServerState" -ne "$lastServerState" ] && echo "$currentServerState" > "$lastServerStateFilePath"
		[ "$currentServerState" -eq 0 ] && break

		tries=$(($tries - 1))
		[ "$tries" -eq 0 ] && break
		sleep 10
	done
}

random0To59() {
	local rand=$(head /dev/urandom | tr -dc "0123456789")
	rand=${rand:0:2}
	[ ${rand:0:1} = "0" ] && rand=${rand:1:2}
	echo $(($rand * 6 / 10))
	# our Ash has not been compiled to work with floats.
}

getStartTime() {
	local startTimeFilePath="$1" interval="$2"

	local startTime
	if [ -f "$startTimeFilePath" ]; then
		local currentTime=$(date +%s)
		startTime=$(cat "$startTimeFilePath")
		# advance timestamp to the closest time after current time that the given interval could produce.
		startTime=$(($startTime + (($currentTime - $startTime) / $interval) * $interval + $interval))
		# that division does not produce a float number. ex: (7/2)*2 = 6.
		# $startTime + (($currentTime - $startTime) / $interval) * $interval 
		# results in the closest time to $currentTime that $interval could 
		# produce, starting from $startTime, that is smaller than $currentTime. 
		# By adding $interval, we get the closest time to $currentTime that 
		# $interval could produce that is bigger than $currentTtime.
		# sleep for the amount of time left to next interval.
		sleep $(($startTime - $currentTime))
		# this makes us always start at the same second, even if the process is shut down for a long time.
	else 
		sleep $(random0To59)
		startTime=$(date +%s)
	fi
	echo $startTime > "$startTimeFilePath"
	echo $startTime
}

cleanFiles() {
	rm "${dataCollectingDir}/serverState" 2> /dev/null
	rm "${rawDataFile}.gz" 2> /dev/null
}

loop() {
	local interval=60
	mkdir -p "$dataCollectingDir"
	local time=$(getStartTime "${dataCollectingDir}/startTime" $interval)

	while true; do
		mkdir -p "$dataCollectingDir"

		eval $(cat /root/flashbox_config.json | jsonfilter \
			-e "hasLatency=@.data_collecting_has_latency" \
			-e "alarmServerAddress=@.data_collecting_alarm_fqdn" \
			-e "pingServerAddress=@.data_collecting_ping_fqdn" \
			-e "pingPackets=@.data_collecting_ping_packets" \
			-e "burstLoss=@.data_collecting_burst_loss" \
			-e "wifiDevices=@.data_collecting_wifi_devices" \
			-e "pingAndWan=@.data_collecting_ping_and_wan" \
		)

		collectData
		sendData

		local endTime=$(date +%s)
		local timeLeftForNextRun="-1"
		while [ "$timeLeftForNextRun" -lt 0 ]; do
			time=$(($time + $interval))
			timeLeftForNextRun=$(($time - $endTime))
		done
		sleep $timeLeftForNextRun

		echo $time > "${dataCollectingDir}/startTime"
	done
}

cleanFiles
loop
