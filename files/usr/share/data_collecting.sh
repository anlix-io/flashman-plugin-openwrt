#!/bin/sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/custom_wireless_driver.sh
. /usr/share/flashman_init.conf

# directory where all data related to data collecting will be stored.
dataCollectingDir="/tmp/data_collecting"
# file where collected data will be stored before being compressed.
rawDataFile="${dataCollectingDir}/raw"
# file where wan rx/tx bytes will be stored
wanBytesFile="${dataCollectingDir}/wan_bytes"
# file where wan rx/tx packets will be stored
wanPacketsFile="${dataCollectingDir}/wan_pkts"

# gets current rx and tx bytes/packets from wan interface and compares them
# with values from previous calls to calculate cross traffic
collect_wan() {
	# checking if this data collecting is enabled

	[ $burstLoss -eq 0 ] && [ $pingAndWan -eq 0 ] && return

	# bytes received by the interface.
	local rxBytes=$(get_wan_bytes_statistics RX)
	# bytes sent by the interface.
	local txBytes=$(get_wan_bytes_statistics TX)

	local string="|wanBytes $rxBytes $txBytes"
	rawData="${rawData}${string}"

	# burstLoss only gathers byte data
	[ $pingAndWan -eq 0 ] && return

	# packets received by the interface.
	local rxPackets=$(get_wan_packets_statistics RX)
	# packets sent by the interface.
	local txPackets=$(get_wan_packets_statistics TX)

	# data to be sent.
	local string="|wanPkts $rxPackets $txPackets"
	rawData="${rawData}${string}"
}

# takes current unix timestamp, executes ping, in burst, to $pingServerAddress server.
# If latency collecting is enabled, extracts the individual icmp request numbers and 
# their respective ping times. Builds a string with all this information and write them to file.
collect_burst() {
	# checking if this data collecting is enabled

	[ $burstLoss -eq 0 ] && [ $pingAndWan -eq 0 ] && return

	# burst ping with $pingPackets amount of packets.
	local pingResult=$(ping -i 0.01 -c "$pingPackets" "$pingServerAddress")
	# ping return value.
	local pingError="$?"

	# if ping could not be executed, we skip this measure.
	[ "$pingError" -eq 2 ] && burstLoss=0 && pingAndWan=0 && return

	# An skipped measure will become missing data, for this minute, in the server.

	# removes everything behind the summary that appears in the last lines.
	local pingResultAux=${pingResult##* ping statistics ---[$'\r\n']}
	# removes everything after, and including, ' packets transmitted'.
	local transmitted=${pingResultAux% packets transmitted*}
	# removes everything after, and including, ' received'.
	local received=${pingResultAux% received*}
	# removes everything before first space.
	received=${received##* }
	# integer representing the amount of packets not received.
	local loss=$(($transmitted - $received))
	# local loss=${pingResult%\% packet loss*} # removes everything after, and including, '% packet loss'.
	# loss=${loss##* } # removes everything before first space.

	# data to be sent.
	local string="$loss $transmitted"

	# removes everything before and including 'mdev = '
	local latencyStats=${pingResult#*/mdev = }

	# when there is 100% packet loss there the strings remain equal
	# we only want to collect latency and std when there isn't 100% loss
	# if loss is 100% we just send 0 in both cases, which will be ignored by the server
	if [ ${#latencyStats} == ${#pingResult} ]; then
	    string="$string 0 0"
	else
		# removes everything before first backslash
		local latencyAvg=${latencyStats#*/}
		# removes everything after first backslash
		latencyAvg=${latencyAvg%%/*}
		# removes everything before and including last backslash
		local latencyStd=${latencyStats##*/}
		# removes everything after and including first space
		latencyStd=${latencyStd%% *}

		string="$string $latencyAvg $latencyStd"
	fi

	# if latency collecting is enabled.
	if [ "$hasLatency" -eq 1 ]; then
		# echo collecting latencies
		# removing the first line and the last 4 lines. only the ping lines remain.
		local latencies=$(printf "%s" "$pingResult" | head -n -4 | sed '1d' | (
		local pairs=""
		local firstLine=true
		# for each ping line.
		while read line; do
			# removes 'time=' part if it exists. if it doesn't, '$reached' will be as long as '$line'.
			reached=${line%time=*}
			# if "time=" has actually been removed, it means that line 
			# contains it, which also means the icmp request was fulfilled.
			# if line doesn't contain 'time=', we skip this line.
			[ ${#reached} -lt ${#line} ] || continue

			 # from the whole line, removes everything until, and including, "icmp_req=".
			pingNumber=${line#*icmp_*eq=}
			# removes everything after the first space.
			pingNumber=${pingNumber%% *}
			# from the whole line, removes everything until, and including, "time=".
			pingTime=${line#*time=}
			# removes everything after the first space.
			pingTime=${pingTime%% *}
			if [ "$firstLine" = true ]; then
				firstLine=false
			else
				pairs="${pairs},"
			fi
			# concatenate to $string.
			pairs="${pairs}${pingNumber}=${pingTime}"
		done
		# prints final $string in this sub shell back to $string.
		echo $pairs))
		# appending latencies to string to be sent.
		[ ${#latencies} -gt 0 ] && string="${string} ${latencies}"
	fi
	
	# appending string to file.
	# printf "string is: '%s'\n" "$string"
	rawData="${rawData}|burstPing $string"
}

collect_wifi_devices() {
	# checking if this data collecting is enabled
	[ "$wifiDevices" -eq 0 ] && return

	# devices and their data will be stored in this string variable.
	local str=""

	local firstRawWrite=1

	# 0 and 1 are the indexes for wifi interfaces: wlan0 and wlan1, or phy0 and phy1.
	for i in 0 1; do
		# getting wifi interface name.
		# 'get_root_ifname()' is defined in /usr/share/functions/custom_wireless_driver.sh.
		local wlan=$(get_root_ifname "$i" 2> /dev/null)
		# if interface doesn't exist, skips this iteration.
		[ -z $wlan ] && continue
		# getting info from each connected device on wifi. 
		# grep returns empty when no devices are connected or if interface doesn't exist.
		local devices="$(iwinfo "$wlan" assoclist | grep ago)"
		local devices_rx_pkts="$(iwinfo "$wlan" assoclist | grep RX | grep -o '[0-9]\+ Pkts')"
		local devices_tx_pkts="$(iwinfo "$wlan" assoclist | grep TX | grep -o '[0-9]\+ Pkts')"

		while [ ${#devices} -gt 0 ]; do

			# getting everything before the first space.
			local deviceMac=${devices%% *}

			# getting everything after the first two spaces.
			local signal=${devices#*  }

			# getting everything before the first occasion of ' /'
			signal=${signal%% /*}

			# if unknown discard
			[ "$signal" == "unknown" ] && devices=${devices#*$'\n'} && continue

			# getting everything before the first occasion of ' dBm'
			signal=${signal%% dBm*}

			# getting after '(SNR '. 
			devices=${devices#*\(SNR }

			# getting everything before the first closing parenthesis.
			local snr=${devices%%\)*}

			# if SNR equals signal we assume noise of -95dBm
			[ $signal -eq $snr ] && snr=$(($signal+95))

			# getting everything before ' ms'.
			local time=${devices%% ms*}

			# getting everything after the first space.
			time=${time##* }

			# getting everything after 'ago'.
			devices=${devices#*ago}

			# getting everything after '\n', if it exists. last line won't have it, so nothing will be changed.
			# we can't add the line feed along witht the previous parameter expansion because we wouldn't match
			# the last line and so we wouldn't make $devices length become zero.
			devices=${devices#*$'\n'}

			# if $time is greater than one minute, we don't use this device's info.
			[ "$time" -gt 60000 ] && continue
			
			local rx_pkts=${devices_rx_pkts%% *}
			devices_rx_pkts=${devices_rx_pkts#*$'\n'}

			local tx_pkts=${devices_tx_pkts%% *}
			devices_tx_pkts=${devices_tx_pkts#*$'\n'}

			[ -z $rx_pkts ] && continue
			[ -z $tx_pkts ] && continue

			# if it's the first data we are storing, don't add a space before appending the data string.
			[ "$firstRawWrite" -eq 1 ] && firstRawWrite=0 || str="$str "
			str="${str}${i}_${deviceMac}_${signal}_${snr}_${rx_pkts}_${tx_pkts}"
		done
	done
	# only send data if there is something to send
	[ -z $str ] && wifiDevices=0 || rawData="${rawData}|wifiDevsStats ${str}"
}

# prints the size of a file, using 'ls', where full file path is given as 
# first argument ($1).
fileSize() {
	# file size is the information at the 1st column.
	local wcline=$(wc -c "$1")
	#remove suffix composed of space and anything else.
	local size=${wcline% *}
	echo $size
}

# prints the sum of the sizes of all files inside given directory path.
sumFileSizesInPath() {
	# boolean that marks that at least one file exists inside given directory.
	local anyFile=0
	# for each file in that directory.
	for i in "$1"/*; do
		# if that pattern expansion exists as a file.
		[ -f "$i" ] || continue
		# set boolean to true.
		anyFile=1
		# as we have at least one file, we don't need to loop through all files.
		break
	done
	# if no files.
	# prints zero. size of nothing is 0.
	# result was given, we can leave function.
	[ "$anyFile" -eq 0 ] && echo 0 && return 0

	# if there is at least one file.

	# prints a list of sizes and files.
	local wcResult=$(wc -c "$1"/*)
	# if there is 2 or more files, the last line will have a "total". remove that string.
	local hasTotal=${wcResult% total}
	# if it has a total, it was removed. if not, nothing was removed and both strings are the same.

	 # if length of string with "total" removed is smaller than original string.
	if [ ${#hasTotal} -lt ${#wcResult} ]; then
		# remove everything before the last word, which is the value for total, and print what remains.
		echo ${hasTotal##* }
	else
		# if there were no total, then there was only one file, in one line of output, and the first column is the size value.
		# remove everything past, and including, the first space, and print what remains.
		echo ${wcResult%% *}
	fi
}

# collect every data and stores in '$rawDataFile'. if the size of the file is 
# too big, compress it and move it to a directory of compressed files. If 
# directory of compressed files grows too big delete oldest compressed files.
collectData() {
	# getting current unix time in seconds.
	local timestamp=$(date +%s)

	# global variable where current raw data is stored before being written to file.
	rawData=""

	# collecting all measures.
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
	# cleaning 'rawData' value from memory.
	rawData=""
}

# if number given as first argument ($1) isn't 0, ping server at address given 
# in second argument ($2) and returns the exit code of $(curl), but if that 
# number is zero, return that number.
checkServerState() {
	local lastState="$1"
	if [ "$lastState" -ne "0" ]; then
		# echo pinging alarm server to check if it's alive.
		curl -s -m 10 "https://$alarmServerAddress:7890/ping" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" > /dev/null
		# return $(curl) exit code.
		lastState="$?"
	fi
	# echo last state is $lastState
	return $lastState
}

# sends file at given path ($1) to server at given address ($2) using $(curl) 
# and returns $(curl) exit code.
sendToServer() {
	local filepath="$1"

	# 'get_mac()' is defined in /usr/share/functions/device_functions.sh.
	local mac=$(get_mac);

	status=$(curl --write-out '%{http_code}' -s -m 20 --connect-timeout 5 --output /dev/null \
	-XPOST "https://$alarmServerAddress:7890/data" -H 'Content-Encoding: gzip' \
	-H 'Content-Type: text/plain' -H "X-ANLIX-ID: $mac" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
	-H "Send-Time: $(date +%s)" --data-binary @"$filepath")
	curlCode="$?"
	# 'log()' is defined in /usr/share/functions/common_functions.sh.
	[ "$curlCode" -ne 0 ] && log "DATA_COLLECTING" "Data sent with curl exit code '${curlCode}'." && return "$curlCode"
	log "DATA_COLLECTING" "Data sent with response status code '${status}'."
	[ "$status" -ge 200 ] && [ "$status" -lt 300 ] && return 0
	return 1
}

# compresses $rawDataFile, sends it to $alarmServerAddress and deletes it. If send was 
# successful, remove original files, if not, keeps it. Returns the return of $(curl).
upload() {
	# if no uncompressed file, nothing wrong, but there's nothing to do in this function.
	[ -f "$rawDataFile" ] || return 0

	# echo going to send uncompressed file
	# the name the compressed file will have.
	local compressedTempFile="${rawDataFile}.gz"
	# remove old file if it exists. it should never be left there.
	[ -f "$compressedTempFile" ] && rm "$compressedTempFile"

	# in case the process is interrupted, delete compressed file.
	trap "rm $compressedTempFile" SIGTERM
	# compressing to a temporary file but keeping original, uncompressed, intact.
	gzip -k "$rawDataFile"

	# sends compressed file.
	sendToServer "$compressedTempFile"
	# storing $(curl) exit code.
	local sentResult="$?"

	# if send was successful, removes original file.
	[ "$sentResult" -eq 0 ] && rm "$rawDataFile"
	# removes temporary file. a new temporary will be created next time, with more content, 
	rm "$compressedTempFile"
	# cleans trap.
	trap - SIGTERM

	return $sentResult # Returns #(curl) exit code.
}


# # reads number written in file, given as first argument ($1), and subtract it by 1. 
# # If that subtraction results in any number that isn't zero, writes that results 
# # to the same file and returns 1. returning 1 means it's not time to send data. 
# # If file doesn't exist, use number given as second argument ($2).
# checkBackoff() {
# 	local backoffCounterPath=$1 defaultBackoff=$2
# 	local counter
# 	if [ -f  "$backoffCounterPath" ]; then # if file exists.
# 		counter=$(cat "$backoffCounterPath") # take number written in that file.
# 	else # if file doesn't exist.
# 		counter=$defaultBackoff # use default value
# 	fi
# 	counter=$(($counter - 1)) # subtract number found on file by 1.
# 	# echo new backoff is $counter
# 	if [ $counter -ne 0 ]; then # if subtraction result is not zero.
# 		echo $counter > "$backoffCounterPath" # write result to file.
# 		return 1 # return 1 means we remain in backoff.
# 	fi
# 	# return 0 means we can send data.
# }

# # given an exit code as first argument ($1), if it's 0, the second argument ($2)
# # is written to file at path given in forth argument ($4), but if it's not 0, the 
# # third argument ($3) is written instead.
# writeBackoff() {
# 	local currentServerState=$1 normalBackoff=$2 changedBackoff=$3 backoffCounterPath=$4
# 	if [ "$currentServerState" -ne 0 ]; then
# 		normalBackoff=$changedBackoff
# 	fi
# 	# echo writting backoff.
# 	echo $normalBackoff > "$backoffCounterPath"
# }

# Attempts to send data some times with 10 seconds of sleep time between tries.
sendData() {
	# echo going to send data
	# amount of attempts of sending data, to alarm server, before giving up.
	local tries=3

	while true; do
		# check if the last time, data was sent, server was alive. if it was, 
		# send compressed data, if everything was sent, send uncompressed 
		# data. If server wasn't alive last time, ping it and if it's alive 
		# now, then send all data, but if it's still dead, do nothing.
		local lastServerStateFilePath="$dataCollectingDir/serverState"
		local lastServerState="1"
		[ -f "$lastServerStateFilePath" ] && lastServerState=$(cat "$lastServerStateFilePath")
		# echo lastServerState=$lastServerState

		checkServerState "$lastServerState" && upload
		local currentServerState="$?"
		# echo currentServerState=$currentServerState
		# if server stops before sending some data, current server state will differ from last server state.
		# $currentServerState get the exit code of the first of these 3 functions above that returns anything other than 0.

		# writes the $(curl) exit code if it has changed since last attempt to send data.
		[ "$currentServerState" -ne "$lastServerState" ] && echo "$currentServerState" > "$lastServerStateFilePath"
		# if data was sent successfully, we stop retrying.
		[ "$currentServerState" -eq 0 ] && break

		tries=$(($tries - 1))
		# leaves retry loop when $retries reaches zero.
		[ "$tries" -eq 0 ] && break
		# echo retrying in 10 seconds
		# sleeps before retrying. this time must take the 60 second interval into consideration.
		sleep 10
	done
}

# echoes a random number between 0 and 59 (inclusive).
random0To59() {
	local rand=$(head /dev/urandom | tr -dc "0123456789")
	# taking the first 2 digits.
	rand=${rand:0:2}
	# "08" and "09" don't work for "$(())".
	[ ${rand:0:1} = "0" ] && rand=${rand:1:2}
	# $rand is a integer between 0 and 99 (inclusive), this makes it an integer between 0 and 59.
	echo $(($rand * 6 / 10))
	# our Ash has not been compiled to work with floats.
}

# prints the time stamp written in file at path given in first argument ($1). 
# that time stamp is used to mark the second when data collecting has started, 
# so we can keep collecting data always at the same interval, without care of 
# how long the data collecting and sending procedures takes. If that files 
# doesn't exist, we sleep for a random time, in order to distribute data 
# collecting time, from all routers, through a minute window, take the current 
# time and write a new file with that time. If it exists, its time stamp is 
# probably from a long time ago, so we advance it forward to a time close to 
# current time, maintaining the correct second the interval, given in second 
# argument ($2), would make it fall into, and sleep for the amount of time 
# left to that second.
getStartTime() {
	local startTimeFilePath="$1" interval="$2"

	local startTime
	# if file holding start time exists.
	if [ -f "$startTimeFilePath" ]; then
		local currentTime=$(date +%s)
		startTime=$(cat "$startTimeFilePath") # get the time stamp inside that file.
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
		# if file holding start time doesn't exist.
		# sleeping for at most 59 seconds to distribute data collecting through a minute window.
		sleep $(random0To59)
		# use current time.
		startTime=$(date +%s)
	fi
	# substitute that time in file, or create a new file.
	echo $startTime > "$startTimeFilePath"
	# print start time found, or current time.
	echo $startTime
}

# deletes files, marking process state, from previous process and deletes temporary
# files that could be hanging if process is terminated in a critical part.
cleanFiles() {
	rm "${dataCollectingDir}/serverState" 2> /dev/null
	# rm "${dataCollectingDir}/backoffCounter" 2> /dev/null
	rm "${rawDataFile}.gz" 2> /dev/null
}

# collects and sends data forever.
loop() {
	# interval between beginnings of data collecting.
	local interval=60
	# making sure directory exists.
	mkdir -p "$dataCollectingDir"
	# time when we will start executing.
	local time=$(getStartTime "${dataCollectingDir}/startTime" $interval)

	# infinite loop where we execute all procedures over and over again until the end of times.
	while true; do
		# echo startTime $time
		# making sure directory exists every time.
		mkdir -p "$dataCollectingDir"

		# getting parameters every time we need to send data, this way we don't have to 
		# restart the service if a parameter changes.
		eval $(cat /root/flashbox_config.json | jsonfilter \
			-e "hasLatency=@.data_collecting_has_latency" \
			-e "alarmServerAddress=@.data_collecting_alarm_fqdn" \
			-e "pingServerAddress=@.data_collecting_ping_fqdn" \
			-e "pingPackets=@.data_collecting_ping_packets" \
			-e "burstLoss=@.data_collecting_burst_loss" \
			-e "wifiDevices=@.data_collecting_wifi_devices" \
			-e "pingAndWan=@.data_collecting_ping_and_wan" \
		)

		# does everything related to collecting and storing data.`
		collectData
		# does everything related to sending data and deletes data sent.
		sendData

		# time after all procedures are finished.
		local endTime=$(date +%s)
		# this will hold the time left until we should run the next iteration of this loop
		local timeLeftForNextRun="-1"
		# while time left is negative, which could happen if $(($time - $endTime)) is bigger than $interval.
		while [ "$timeLeftForNextRun" -lt 0 ]; do
			# advance time, when current data collecting has started, by one interval.
			time=$(($time + $interval))
			# calculate time left to collect data again.
			timeLeftForNextRun=$(($time - $endTime))
		done
		# echo timeLeftForNextRun=$timeLeftForNextRun
		 # sleep for the time remaining until next data collecting.
		sleep $timeLeftForNextRun

		# writing next loop time to file that, at this line, matches current time.
		echo $time > "${dataCollectingDir}/startTime"
	done
}

# deletes files, marking process state, from previous process.
cleanFiles
# the infinite loop.
loop
