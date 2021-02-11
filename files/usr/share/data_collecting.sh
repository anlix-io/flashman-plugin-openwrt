#!/bin/sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/data_collecting_functions.sh

dataCollectingDir="/tmp/data_collecting"
rawDataFile="${dataCollectingDir}/raw"
compressedDataDir="${dataCollectingDir}/compressed"

# # prints the name of all available wireless interfaces, separated by new lines.
# getAllInterfaceNames() {
# 	local index=0 name
# 	while true; do
# 		name=$(uci -q get wireless.default_radio$index.ifname)
# 		if [ "$?" -ne 0 ]; then break; fi
# 		echo $name
# 		index=$(($index + 1))
# 	done
# }

# # extract data from devices in wifi, builds a string in influx line protocol 
# # format, which uses the router's mac address ($2) to identify the router 
# # each device belongs to, and append that string to file given as first 
# # argument ($1).
# collectDevicesWifiDataForInflux() {
# 	local filepath="$1" mac="$2"

# 	local timestamp=$(date +%s) # getting current unix time in seconds.
# 	local allDevices oneDevice snr

# 	for interface in $(getAllInterfaceNames); do # for each interface in the router;
# 		# extracting the signal to noise ratio value from the interface.
# 		snr=$(iwinfo ${interface} assoclist) # interface info where we will take the snr value.
# 		snr=${snr#*\(SNR } # removes everything until "(SNR " including it.
# 		snr=${snr%%\)*} # removes everything past "\)" including it.

# 		allDevices=$(iw dev ${interface} station dump); # this prints only if there is any device connected to wifi.
# 		while [ "$allDevices" ]; do
# 			oneDevice=${allDevices##*Station }; # removes, from $allDevices, the biggest match before and including "Station ".
# 			allDevices=${allDevices%Station *}; # removes, from $allDevices, the smallest match after and including "Station ".

# 			# following command extract fields from one device and builds a 
# 			# string as influx line protocol format and append that to a file.
# 			echo $oneDevice | sed "
# 			s/\([0-9a-f:]*\).* rx bytes: \([0-9]*\).*rx packets: \([0-9]*\).*tx bytes: \([0-9]*\).*tx packets: \([0-9]*\).*signal:\s*\([-0-9]*\)\s.*dBm.*tx bitrate: \([0-9]*\.[0-9]*\).*rx bitrate: \([0-9]*\.[0-9]*\).*/wifi,d=\1,r=${mac} rx=\8,rxb=\2i,rxp=\3i,sig=\6i,snr=${snr}i,tx=\7,txb=\4i,txp=\5i ${timestamp}/
# 			s/://g" >> "$filepath";
# 		done
# 	done
# }

# # gets wan info from /sys/class/net/$wanName/statistics/ and builds a string 
# # in influx line protocol format, which uses the router's mac address, given 
# # as second argument ($2), to identify the router, and append that string to 
# # file given as first argument ($1).
# collectWanStatisticsForInflux() {
# 	local filepath="$1" mac="$2"

# 	local timestamp=$(date +%s) # getting current unix time in seconds.
# 	local wanName=$(ifstatus wan | jsonfilter -e '@.device') # name of the wan interface.
# 	local rxBytes=$(cat /sys/class/net/$wanName/statistics/rx_bytes)
# 	local txBytes=$(cat /sys/class/net/$wanName/statistics/tx_bytes)
# 	local rxPackets=$(cat /sys/class/net/$wanName/statistics/rx_packets)
# 	local txPackets=$(cat /sys/class/net/$wanName/statistics/tx_packets)
# 	local string="wan,r=$mac rxb=${rxBytes}i,rxp=${rxPackets}i,txb=${txBytes}i,txp=${txPackets}i $timestamp"
# 	# echo s$string
# 	echo "$string" >> "$filepath"
# }

# # executes 100 pings, in burst, to flashman server, extracts the individual 
# # icmp request number and its respective ping time and builds a string in
# # influx line protocol format, which uses the router's mac address, given 
# # as second argument ($2), to identify the router, and append that string 
# # to file given as first argument ($1).
# collectPingForInflux() {
# 	local filepath="$1" mac="$2"

# 	local timestamp=$(date +%s) # getting current unix time in seconds.
# 	local string="ping,r=$mac " # beginning of influx line protocol string.
# 	local pingNumber pingTime unreachable

# 	local pingResult=$(ping -i 0.01 -c 100 "$FLM_SVADDR") # 100 pings in burst.

# 	# as numerical characters are small than letters, the icmp request numbers 
# 	# are written first to string, then the letters charactered fields are 
# 	# written.

# 	# removing the first line and the last 4 lines. only the ping lines remain.
# 	string=$(printf "%s" "$pingResult" | head -n -4 | sed '1d' | (while read line; do # for each ping line.
# 		reached=${line%time=*} # removes 'time=' part if it exists.
# 		# if "time=" has actually been removed, it means that line 
# 		# contains it, which also means the icmp request was fulfilled.
# 		[ ${#reached} -lt ${#line} ] || continue # if line doesn't contain 'time=', skip this line.

# 		pingNumber=${line#*icmp_req=} # from the whole line, removes everything until, and including, "icmp_req=".
# 		pingNumber=${pingNumber%% *} # removes everything after the first space.
# 		pingTime=${line#*time=} # from the whole line, removes everything until, and including, "time=".
# 		pingTime=${pingTime%% *} # removes everything after the first space.
# 		string="${string}$pingNumber=$pingTime," # concatenate to $string.
# 	done
# 	echo $string)) # prints final $string in this sub shell back to $string.
	
# 	pingResult=${pingResult##* ---} # the summary that appears in the last lines.
# 	local loss=${pingResult%\% packet loss*} # removes everything after, and including, '% packet loss'.
# 	loss=${loss##* } # removes everything after first space.
# 	if [ $loss -ne 100 ]; then # if $loss is not '100'.
# 		# takes average after removing everything until, and including first digit followed by '/'.
# 		local average=${pingResult#*[0-9]/}
# 		average=${average%%/*} # removes everything after first '/'.
# 		string="${string}avg=$average," # append average information.
# 	fi # when loss is 100%, no rtt information is present in ping result, which means there is no average, min or max info.
# 	string="${string}loss=${loss}i ${timestamp}" # append loss information and $timestamp to string.

# 	# printf "string is: '%s'\n" "$string"
# 	echo "$string" >> "$filepath" # appending string to file.
# }

# takes current unis timestamp, executes 100 pings, in burst, to flashman 
# server, gets current rx and tx bytes from wlan interface and compares then 
# with values from previous calls to calculate cross traffic, if latency 
# collecting is enabled, extracts the individual icmp request numbers and their 
# respective ping times to build a string with all this information and write 
# them to file given as first argument ($1).
collect_QoE_Monitor_data() {
	local filepath="$1"

	# echo collecting data and writing to file $filepath

	local timestamp=$(date +%s) # getting current unix time in seconds.
	local pingResult=$(ping -i 0.01 -c 100 "$FLM_SVADDR") # 100 pings in burst.

	pingResult=${pingResult##* ---} # the summary that appears in the last lines.
	local loss=${pingResult%\% packet loss*} # removes everything after, and including, '% packet loss'.
	loss=${loss##* } # removes everything after first space.

	local wanName=$(ifstatus wan | jsonfilter -e '@.device') # name of the wan interface.
	local rxBytes=$(cat /sys/class/net/$wanName/statistics/rx_bytes) # bytes received by the interface.
	local txBytes=$(cat /sys/class/net/$wanName/statistics/tx_bytes) # bytes sent by the interface.
	local max_bytes=4294967295 # max number possible with 32 bits. (2^32 - 1).
	
	
	local rx=${last_rxBytes:=$rxBytes} # if '$last_rxBytes' is undefined, we will use the current value as last value.
		# this means the difference, between current value and last value, will be 0 in the first execution.
	rx=$(($rxBytes - $last_rxBytes)) # subtract previous interface value from the current value.
	if [ $rx -lt 0 ]; then rx=$(($rx + $max_bytes)); fi # if subtraction created a negative value, it means it has overflown.
	last_rxBytes=$rxBytes # save current interface value as last value.

	local tx=${last_txBytes:=$txBytes}
	tx=$(($txBytes - $last_txBytes))
	if [ $tx -lt 0 ]; then tx=$(($tx + $max_bytes)); fi
	last_txBytes=$txBytes

	local string="$timestamp $loss $rx $tx" # data to be sent.

	# if latency collecting is enabled.
	if [ "$(get_flashman_parameter data_collecting_latency)" = "1" ]; then
		# echo collecting latencies
		# removing the first line and the last 4 lines. only the ping lines remain.
		local latencies=$(printf "%s" "$pingResult" | head -n -4 | sed '1d' | (
		local firstLine=true
		while read line; do # for each ping line.
			reached=${line%time=*} # removes 'time=' part if it exists.
			# if "time=" has actually been removed, it means that line 
			# contains it, which also means the icmp request was fulfilled.
			[ ${#reached} -lt ${#line} ] || continue # if line doesn't contain 'time=', skip this line.

			pingNumber=${line#*icmp_*eq=} # from the whole line, removes everything until, and including, "icmp_req=".
			pingNumber=${pingNumber%% *} # removes everything after the first space.
			pingTime=${line#*time=} # from the whole line, removes everything until, and including, "time=".
			pingTime=${pingTime%% *} # removes everything after the first space.
			if [ "$firstLine" = true ]; then
				firstLine=false
			else
				string="${string},"
			fi
			string="${string}${pingNumber}=${pingTime}" # concatenate to $string.
		done
		echo $string)) # prints final $string in this sub shell back to $string.
		string="${string} ${latencies}" # appending latencies to string to be sent.
	fi

	# printf "string is: '%s'\n" "$string"
	echo "$string" >> "$filepath"; # appending string to file.
}

# prints the size of a file, using 'ls', where full file path is given as 
# first argument ($1).
fileSize() {
	local wcline=$(wc -c "$1") # file size is the information at the 1st column.
	local size=${wcline% *} #remove suffix composed of space and anything else.
	echo $size
}

# prints the sum of the sizes of all files inside given directory path.
sumFileSizesInPath() {
	local anyFile=false # boolean that marks that at least one file exists inside given directory.
	for i in "$1"/*; do # for each file in that directory.
		[ -f "$i" ] || continue # if that pattern expansion exists as a file.
		anyFile=true # set boolean to true.
		break # as we have at least one file, we don't need to loop through all files.
	done
	if [ "$anyFile" = false ]; then # if no files.
		echo 0 # prints zero. size of nothing is 0.
		return 0 # result was given, we can leave function.
	fi
	# if there is at least one file.

	local wcResult=$(wc -c "$1"/*) # prints a list of sizes and files.
	local hasTotal=${wcResult% total} # if there is 2 or more files, the last line will have a "total". remove that string.
	# if it has a total, it was removed. if not, nothing was removed and both strings are the same.

	if [ ${#hasTotal} -lt ${#wcResult} ]; then # if length of string with "total" removed is smaller than original string.
		echo ${hasTotal##* } # remove everything before the last word, which is the value for total, and print what remains.
	else # if there were no total, then there was only one file, in one line of output, and the first column is the size value.
		echo ${wcResult%% *} # remove everything past, and including, the first space, and print what remains.
	fi
}

# sum the size of the file, given in first argument ($1), where raw data is 
# written to, with the size of all compressed files inside the directory given 
# in second argument ($2). if that sum is bigger than number given in third 
# argument ($3), compress that file and move it to that directory.
zipFile() {
	local fileToCompress="$1" compressedFilesDir="$2" capSize="$3"

	# if file doesn't exist, we won't have to compressed anything.
	[ -f "$fileToCompress" ] || return 1 # a return of 1 means nothing has been be gzipped.

	local size=$(fileSize "$fileToCompress") # size of file with raw data.
	local dirSize=$(sumFileSizesInPath "$compressedFilesDir") # sum of file sizes in directory for compressed files.

	# if sum is smaller than $capSize, do nothing.
	# echo checking file size to zip
	if [ $(($size + $dirSize)) -lt $capSize ]; then return 1; fi # a return of 1 means nothing will be gzipped.

	# compressing file where raw data is held.
	gzip "$fileToCompress"
	# move newly compressed file to directory where compressed files should be.
	mv "${fileToCompress}.gz" "$compressedFilesDir/$(date +%s).gz"
}

# given file paths in first argument ($1), starting from first to last, files 
# are removed until all data remaining is below number given in second 
# argument ($2). As files are named using a formatted date, pattern expansion 
# of file names will always order oldest files first. This was done this way 
# so we don't have to sort files by date ourselves. we let shell do the 
# sorting.
removeOldFiles() {
	local dirPath="$1" capSize="$2"

	local dirSize=$(sumFileSizesInPath "$dirPath")

	# if $dirSize is more than given $capSize, remove oldest file. which is 
	# the file that shell orders as first.
	for i in "$filesPaths"/*; do
		[ $dirSize -lt $capSize ] && break; # if we are under $capSize. do nothing.
		rm "$i" # removes that file.
		dirSize=$(($dirSize - $(fileSize "$i"))) # subtract that file's size from sum.
	done
}

# collect every data and stores in '$rawDataFile'. if the size of the file is 
# too big, compress it and move it to a directory of compressed files. If 
# directory of compressed files grows too big delete old compressed files.
collectData() {
	collect_QoE_Monitor_data "$rawDataFile"

	# $(zipFile) returns 0 only if any amount of files has been compressed 
	# and, consequently, moved to the directory of compressed files. So
	# $(removeOldFiles) is only executed if any new compressed file was 
	# created.
	mkdir -p "$compressedDataDir"
	zipFile "$rawDataFile" "$compressedDataDir" $((32*1024)) && \
		removeOldFiles "$compressedDataDir" $((24*1024))
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
	local lastState=$1 serverAddress=$2
	if [ "$lastState" != "0" ]; then
		curl -sl -I "https://$serverAddress:7890/ping" > /dev/null # check if server is alive.
		lastState="$?" #return $(curl) exit code.
	fi
	# echo last state it $lastState
	return $lastState
}

# sends file at given path ($1) to server at given address ($2) using $(curl) 
# and returns $(curl) exit code.
sendToServer() {
	local filepath="$1" serverAddress="$2"

	local mac=$(get_mac); # defined in /usr/share/functions/device_functions.sh
	mac=${mac//:/} # removing all colons in mac address.

	curl -s -m 20 --connect-timeout 5 \
	-XPOST "https://$serverAddress:7980/w/$mac" \
	-H 'Content-Encoding: gzip' -H 'Content-Type: application/octet-stream' \
	-H "X-ANLIX-ID: $mac" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
	--data-binary @"$filepath"
	return "$?"
}

# for each compressed file given in first argument ($1), send that file to a 
# server at address given in second argument ($2). If any sending is 
# unsuccessful, stops sending files and return it's exit code.
sendCompressedData() {
	local compressedFilesPaths="$1" serverAddress="$2"

	# echo going to send compressed data
	# echo $compressedFilesPaths

	local sentResult
	for i in $compressedFilesPaths; do # for each compressed file in the pattern expansion.
		# echo checking existence of file $i
		[ -f "$i" ] || continue # check if file still exists.

		# echo sending file $i
		sendToServer "$i" "$serverAddress" # sends file.
		sentResult="$?" # store $(curl) exit code.

		if [ "$sentResult" -eq 0 ]; then # if $(curl) exit code is equal to 0.
			rm "$i" # remove file.
		else # but if $(curl) exit code isn't equal to 0.
			return "$sentResult" # return $(curl) exit code without deleting the file we tried to send.
		fi
	done
}

# compresses file given in first argument ($1), sends it to a server at 
# address given in second argument ($3) and deletes it. If send was successful, 
# remove original files, if not, keeps it. Returns the return of $(curl).
sendUncompressedData() {
	local uncompressedFile="$1" serverAddress="$2"

	# if no uncompressed file, nothing wrong, but there's nothing to do in this function.
	[ -f "$uncompressedFile" ] || return 0

	# echo going to send uncompressed files
	local compressedTempFile="${uncompressedFile}.gz" # the name the compressed file will have.
	# remove old file if it exists. it should never be left there.
	if [ -f "$compressedTempFile" ]; then rm "$compressedTempFile"; fi

	trap "rm $compressedTempFile" SIGTERM # in case the process is interrupted, delete compressed file.
	gzip -k "$uncompressedFile" # compressing to a temporary file but keeping original, uncompressed, intact.

	sendToServer "$compressedTempFile" "$serverAddress" # sends compressed file.
	local sentResult="$?" # storing $(curl) exit code.

	[ "$sentResult" -eq 0 ] && rm "$uncompressedFile" # if send was successful, removes original file.
	rm "$compressedTempFile" # removes temporary file. a new temporary will be created next time, with more content, 
		# if we couldn't send data this time.
	trap - SIGTERM # cleans trap.

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

# gets server fqdn where data should be sent to and attempts to send data some 
# times with 10 seconds of sleep time between tries.
sendData() {
	# echo going to send data
	local tries=4
	while true; do
		# getting fqdn every time we need to send data, this way we don't have to 
		# restart the service if fqdn changes.
		local dataCollectingFqdn=$(get_flashman_parameter data_collecting_fqdn)

		local 

		="$dataCollectingDir/serverState"
		# check if the last time, data was sent, server was alive. if it was, 
		# send compressed data, if everything was sent, send uncompressed 
		# data. If server wasn't alive last time, ping it and if it's alive 
		# now, then send all data, but if it's still dead, do nothing.
		local lastServerState="1"
		[ -f "$lastServerStateFilePath" ] && lastServerState=$(cat "$lastServerStateFilePath")

		checkServerState "$lastServerState" "$dataCollectingFqdn" && \
		sendCompressedData "${compressedDataDir}/*" "$dataCollectingFqdn" && \
		sendUncompressedData "$rawDataFile" "$dataCollectingFqdn"
		local currentServerState="$?"
		# if server stops before sending some data, current server state will differ from last server state.
		# $currentServerState get the exit code of the first of these 3 functions above that returns anything other than 0.

		# writes the $(curl) exit code if it has changed since last attempt to send data.
		[ "$currentServerState" != "$lastServerState" ] && echo "$currentState" > "$lastServerStateFilePath"
		[ "$currentServerState" -eq 0 ] && break # if data was sent successfully, we stop retrying.

		tries=$(($tries - 1))
		[ "$tries" -eq 0 ] && break # leaves retry loop when $retries reaches zero.
		# echo retrying in 10 seconds
		sleep 10 # sleeps before retrying.
	done
}

# prints the timestamp written in file at path given in first argument ($1). 
# that timestamp is used to mark the second when data collection has started, 
# so we can keep collecting data always at the same interval, without care of 
# how long the data collecting and sending procedures takes. If that files 
# doesn't exist, we use current time and write a new file with that time. If 
# it exists, its timestamp is probably of a long time ago, so we advance it 
# forward to a time close to current time, maintaining the correct second the 
# interval, given in second argument ($2), would make it fall into, and sleep
# for the amount of time left to that second.
getStartTime() {
	local startTimeFilePath="$1" interval=$2

	local currentTime=$(date +%s)
	local startTime
	if [ -f $startTimeFilePath ]; then # if file holding start time exists.
		startTime=$(cat $startTimeFilePath) # get the timestamp inside that file.
		# advance timestamp to the closest time after current time that the given interval could produce.
		startTime=$(($startTime + (($currentTime - $startTime) / $interval) * $interval + $interval))
		# that division does not produce a float number. ex: (7/2)*2 = 6.
		# $startTime + (($currentTime - $startTime) / $interval) * $interval 
		# results in the closest time to $currentTime that $interval could 
		# produce, starting from $startTime, that is smaller than $currentTime. 
		# By adding $interval, we get the closest time to $currentTime that 
		# $interval could produce that is bigger than $currentTtime.
		sleep $(($startTime - $currentTime)) # sleep for the amount of time left to next interval.
		# this makes us always start at the same second, even if the process is shut down for a long time.
	else # if file holding start time doesn't exist.
		startTime=$currentTime # use current time.
	fi
	echo $startTime > $startTimeFilePath # substitute that time in file, or create a new file.
	echo $startTime # print start time found, or current time.
}

# deletes files, marking process state, from previous process and deletes 
# temporary files that could be hanging if process is terminated in a critical 
# part.
cleanFiles() {
	rm "${dataCollectingDir}/serverState" 2> /dev/null
	# rm "${dataCollectingDir}/backoffCounter" 2> /dev/null
	rm "${rawDataFile}.gz" 2> /dev/null
}

# collects and sends data forever.
loop() {
	local interval=60 # interval between beginnings of data collecting.
	mkdir -p "$dataCollectingDir" # making sure directory exists every time.
	local time=$(getStartTime "$dataCollectingDir/startTime" $interval) # time when we will start executing.

	while true; do # infinite loop where we execute all procedures over and over again until the end of times.
		# echo startTime $time

		collectData # does everything related to collecting and storing data.
		sendData # does everything related to sending data and deletes data sent.

		local endTime=$(date +%s) # time after all procedures are finished.
		local timeLeftForNextRun="-1" # this will hold the time left until we should run the next iteration of this loop
		# while time left is negative, which could happen if $(($time - $endTime)) is bigger than $interval.
		while [ "$timeLeftForNextRun" -lt 0 ]; do
			time=$(($time + $interval)) # advance time, when current data collecting has started, by one interval.
			timeLeftForNextRun=$(($time - $endTime)) # calculate time left to collect data again.
		done
		sleep $timeLeftForNextRun # sleep for the time remaining until next data collecting.
	done
}

cleanFiles # deletes files, marking process state, from previous process.
loop
