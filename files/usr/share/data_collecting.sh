#!/bin/sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/custom_wireless_driver.sh
. /usr/share/flashman_init.conf

# directory where all data related to data collecting will be stored.
dataCollectingDir="/tmp/data_collecting"
# file where collected data will be stored before being compressed.
rawDataFile="${dataCollectingDir}/raw"
# directory where data will be stored if compressing old data is necessary.
compressedDataDir="${dataCollectingDir}/compressed"
# file where connectivity pings are stored.
connectivityPingsFile="${dataCollectingDir}/connpings"

rawData=""

# takes current unix timestamp, executes ping, in burst, to $pingServerAddress server, gets current 
# rx and tx bytes from wan interface and compares then with values from previous calls to calculate 
# cross traffic. If latency collecting is enabled, extracts the individual icmp request numbers and 
# their respective ping times. Builds a string with all this information and write them to file.
collect_QoE_Monitor_data() {
	# checking if this data collecting is enabled
	[ "$burstLoss" -ne 1 ] && return

	# burst ping with $pingPackets amount of packets.
	local pingResult=$(ping -i 0.01 -c "$pingPackets" "$pingServerAddress")
	# ping return value.
	local pingError="$?"

	# Even if the ping could not be executed, we'll read the wan bytes to keep tracking the amount of bytes up and down.

	# bytes received by the interface.
	local rxBytes=$(get_wan_statistics RX)
	# bytes sent by the interface.
	local txBytes=$(get_wan_statistics TX)

	# if last bytes are not defined. define them using the current wan interface bytes value. then we skip this measure.
	if [ -z "$last_rxBytes" ] || [ -z "$last_txBytes" ]; then
		# echo last bytes are undefined
		# bytes received by the interface. will be used next time.
		last_rxBytes="$rxBytes"
		# bytes sent by the interface. will be used next time.
		last_txBytes="$txBytes"
		# don't write data this round. we need a full minute of bytes to calculate cross traffic.
		return
	fi

	# bytes received since last time.
	local rx=$(($rxBytes - $last_rxBytes))
	# bytes transmitted since last time
	local tx=$(($txBytes - $last_txBytes))
	# if subtraction created a negative value, it means it has overflown or interface has been restarted.
	# we skip this measure.
	{ [ "$rx" -lt 0 ] || [ "$tx" -lt 0 ]; } && return
	# saves current interface bytes value as last value.
	last_rxBytes=$rxBytes
	# saves current interface bytes value as last value.
	last_txBytes=$txBytes

	# if ping could not be executed, we skip this measure.
	[ "$pingError" -eq 2 ] && return;

	# An skipped measure will become missing data, for this minute, in the server.

	# removes everything behind the summary that appears in the last lines.
	pingResult=${pingResult##* ping statistics ---[$'\r\n']}
	# removes everything after, and including, ' packets transmitted'.
	local transmitted=${pingResult% packets transmitted*}
	# removes everything after, and including, ' received'.
	local received=${pingResult% received*}
	# removes everything before first space.
	received=${received##* }
	# integer representing the amount of packets not received.
	local loss=$(($transmitted - $received))
	# local loss=${pingResult%\% packet loss*} # removes everything after, and including, '% packet loss'.
	# loss=${loss##* } # removes everything before first space.

	local string="$loss $transmitted $rx $tx" # data to be sent.

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
		string="${string} ${latencies}"
	fi
	
	# appending string to file.
	# printf "string is: '%s'\n" "$string"
	rawData="${rawData}|burstLoss ${string}"
}

collect_connectivity_pings() {
	# checking if this data collecting is enabled.
	[ "$connPings" -ne 1 ] && return

	# content from pings file will be assign to this variable.
	local pings
	# boolean that will become false if connectivity pings file is not empty.
	local empty=true
	# using a lock file, in writing mode, to block code while accessing the pings file.
	# this is to prevent writing conflict to the script that writes new values to the pings file.
	{
	flock -x 9
	# reading connectivity pings file and writing errors to '/dev/null'. 
	pings=$(cat "$connectivityPingsFile" 2> /dev/null) && \
		# if file could be read and if amount of lines is greater than zero, sets 'empty' to false and removes file. 
		[ $(printf "%s" "$pings" | wc -l) -gt 0 ] && empty=false && rm "$connectivityPingsFile"
	# "${connectivityPingsFile}lock" is also used by the script that writes new values to the file.
	} 9>"${connectivityPingsFile}lock"

	# if there are no pings, we do nothing.
	[ "$empty" == true ] && return

	# counter and total for pings. we later divide them to get an average.
	local count=0
	local average=0
	for rtt in $pings; do
		count=$(($count + 1))
		# removing floating point. which means multiplying by 1000 as 'ping' times always have 3 floating point digits.
		# we are using integers only in our math because flashboxes don't have floating point numbers in ash.
		average=$(($average + ${rtt//.}))
	done

	# using integer division isn't perfect but it's precise enough for us.
	average=$(($average / $count))
	# dividing back by 1000 by just manipulating the string. Putting a dot before the last 3 digits.
	local dotPosition=$((${#average}-3))
	average="${average:0:$dotPosition}.${average:$dotPosition}"
	rawData="${rawData}|connPings ${average} ${count}"
}

collect_wifi_devices() {
	# checking if this data collecting is enabled
	[ "$wifiDevices" -ne 1 ] && return

	# devices and their data will be stored in this string variable.
	local str=""
	# 0 and 1 are the indexes for wifi interfaces: wlan0 and wlan1, or phy0 and phy1.
	for i in 0 1; do
		# getting wifi interface name.
		# 'get_root_ifname()' is defined in /usr/share/functions/custom_wireless_driver.sh.
		local lan=$(get_root_ifname "$i" 2> /dev/null)
		# if interface doesn't exist, skips this iteration.
		[ "$lan" == "" ] && continue
		# getting info from each connected device on wifi. 
		# grep returns empty when no devices are connected or if interface doesn't exist.
		local devices="$(iwinfo "$lan" assoclist | grep ago)"

		# first iteration won't put a space before the value.
		local first=true
		while [ ${#devices} -gt 0 ]; do
			# getting everything before the first space.
			local deviceMac=${devices%% *}
			# getting after '(SNR '. 
			devices=${devices#*\(SNR }
			# getting everything before the first closing parenthesis.
			local snr=${devices%%\)*}
			# getting everything before ' ms'.
			local time=${devices%% ms*}
			# getting everything after the first space.
			time=${time##* }
			# getting after 'ago'.
			devices=${devices#*ago}
			# getting after '\n'. if it exists. last line won't have it, so nothing will be changed.
			devices=${devices#*$'\n'}
			# if time is greater than one minute, we don't use this device's info.
			[ "$time" -gt 60000 ] && continue
			# if it's the first data we are storing, don't add a space before appending the data string.
			[ "$first" == true ] && first=false || str="$str "
			str="${str}${lan}-${deviceMac}-${snr}"
		done
	done
	# we won't echo if there are no devices.
	[ ${#str} -gt 0 ] && rawData="${rawData}|wifiDevices ${str}"
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
	local anyFile=false
	# for each file in that directory.
	for i in "$1"/*; do
		# if that pattern expansion exists as a file.
		[ -f "$i" ] || continue
		# set boolean to true.
		anyFile=true
		# as we have at least one file, we don't need to loop through all files.
		break
	done
	if [ "$anyFile" = false ]; then
		# if no files.
		# prints zero. size of nothing is 0.
		echo 0
		# result was given, we can leave function.
		return 0
	fi
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

# sum the size $rawDataFile with the size of all compressed files inside the $compressedDataDir. if that 
# sum is bigger than number given in first argument ($1), compress that file and move it to $compressedDataDir.
zipFile() {
	local capSize="$1"

	# if file doesn't exist, we won't have to compressed anything.
	# a return of 1 means nothing has been be gzipped.
	[ -f "$rawDataFile" ] || return 1 

	# size of file with raw data.
	local size=$(fileSize "$rawDataFile")
	# sum of file sizes in directory for compressed files.
	local dirSize=$(sumFileSizesInPath "$compressedDataDir")

	# if sum is smaller than $capSize, do nothing.
	# echo checking file size to zip
	# a return of 1 means nothing will be gzipped.
	[ $(($size + $dirSize)) -lt $capSize ] && return 1

	# compressing file where raw data is held.
	gzip "$rawDataFile"
	# move newly compressed file to directory where compressed files should be.
	mv "${rawDataFile}.gz" "$compressedDataDir/$(date +%s).gz"
}

# files are removed from $compressedDataDir until all data remaining is below number given in first 
# argument ($1) as bytes. As files are named using a formatted date, pattern expansion of file 
# names will always order oldest files first. This was done this way so we don't have to sort files 
# by date ourselves. we let shell do the sorting.
removeOldFiles() {
	local capSize="$1"

	# get the sum of sizes of all files in bytes.
	local dirSize=$(sumFileSizesInPath "$compressedDataDir")

	# if $dirSize is more than given $capSize, remove oldest file. which is 
	# the file that shell orders as first.
	for i in "$compressedDataDir"/*; do
		# if we are under $capSize. do nothing.
		[ $dirSize -lt $capSize ] && break;
		# removes that file.
		rm "$i"
		# subtract that file's size from sum.
		dirSize=$(($dirSize - $(fileSize "$i")))
	done
}

# collect every data and stores in '$rawDataFile'. if the size of the file is 
# too big, compress it and move it to a directory of compressed files. If 
# directory of compressed files grows too big delete oldest compressed files.
collectData() {
	# getting current unix time in seconds.
	local timestamp=$(date +%s)

	# collecting all measures.
	collect_QoE_Monitor_data
	collect_connectivity_pings
	collect_wifi_devices

	# example of an expected raw data with all measures present:
	# '213234556456|burstLoss 0 100 12345 1234|connPings 10.344 30|wifiDevices aa:bb:cc:dd:ee:ff-22 ab:bb:cc:dd:ee:ff-45'
	[ -n "$rawData" ] && echo "${timestamp}${rawData}" >> "$rawDataFile";
	# cleaning 'rawData' value from memory and making it ready for next minute.
	rawData=""

	# $(zipFile) returns 0 only if any amount of files has been compressed 
	# and, consequently, moved to the directory of compressed files. So
	# $(removeOldFiles) is only executed if any new compressed file was 
	# created.

	# creates directory of for compressed files, if it doesn't already exists.
	mkdir -p "$compressedDataDir"
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

# for each compressed file given in $compressedDataDir, send that file to a $alarmServerAddress. 
# If any sending is unsuccessful, stops sending files and return it's exit code.
sendCompressedData() {
	# echo going to send compressed files
	# echo "$compressedDataDir"/*
	# for each compressed file in the pattern expansion.
	for i in "$compressedDataDir"/*; do
		# if file exists, sends file and if $(curl) exit code isn't equal to 0, returns $(curl) exit code 
		# without deleting the file we tried to send. if $(curl) exit code is equal to 0, removes file
		[ -f "$i" ] && { sendToServer "$i" || return "$?"; } && rm "$i"
	done
	return 0
}

# compresses $rawDataFile, sends it to $alarmServerAddress and deletes it. If send was 
# successful, remove original files, if not, keeps it. Returns the return of $(curl).
sendUncompressedData() {
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

		checkServerState "$lastServerState" && sendCompressedData && sendUncompressedData
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
	rm "${connectivityPingsFile}lock"
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
			-e "connPings=@.data_collecting_conn_pings" \
			-e "wifiDevices=@.data_collecting_wifi_devices" \
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
