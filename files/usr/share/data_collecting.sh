#!/bin/sh
. /usr/share/functions/device_functions.sh
. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh

dataCollectingDir="/tmp/data_collecting" # directory where all data related to data collecting will be stored.
rawDataFile="${dataCollectingDir}/raw" # file collected data will be stored before being compressed.
compressedDataDir="${dataCollectingDir}/compressed" # directory where data will be stored if compressing old data is necessary.

# takes current unix timestamp, executes ping, in burst, to $pingServerAddress server, gets current 
# rx and tx bytes from wan interface and compares then with values from previous calls to calculate 
# cross traffic. If latency collecting is enabled, extracts the individual icmp request numbers and 
# their respective ping times. Builds a string with all this information and write them to file.
collect_QoE_Monitor_data() {
	# echo collecting data and writing to file

	local timestamp=$(date +%s) # getting current unix time in seconds.
	local pingResult=$(ping -i 0.01 -c "$pingPackets" "$pingServerAddress") # burst ping with $pingPackets amount of packets.

	local rxBytes=$(get_wan_statistics RX) # bytes received by the interface.
	local txBytes=$(get_wan_statistics TX) # bytes sent by the interface.
	local max_bytes=4294967295 # max number possible with 32 bits. (2^32 - 1).
	# if last bytes are not defined. define them using the current wan interface bytes value. then it returns.
	if [ -z "$last_rxBytes" ] || [ -z "$last_txBytes"]; then
		# echo last bytes are undefined
		last_rxBytes="$rxBytes" # bytes received by the interface. will be used next time.
		last_txBytes="$txBytes" # bytes sent by the interface. will be used next time.
		return # don't write data this round. we need a full minute of bytes to calculate cross traffic.
	fi
	local rx=$(($rxBytes - $last_rxBytes)) # subtract previous interface value from the current value.
	local tx=$(($txBytes - $last_txBytes)) # subtract previous interface value from the current value.
	[ "$rx" -lt 0 ] && rx=$(($rx + $max_bytes)) # if subtraction created a negative value, it means it has overflown.
	[ "$tx" -lt 0 ] && tx=$(($tx + $max_bytes)) # if subtraction created a negative value, it means it has overflown.
	last_rxBytes=$rxBytes # saves current interface bytes value as last value.
	last_txBytes=$txBytes # saves current interface bytes value as last value.

	pingResult=${pingResult##* ---[$'\r\n']} # removes everything behind the summary that appears in the last lines.
	local transmitted=${pingResult% packets transmitted*} # removes everything after, and including, ' packets transmitted'.
	local received=${pingResult% received*} # removes everything after, and including, ' received'.
	received=${received##* } # removes everything before first space.
	local loss=$(($transmitted - $received)) # integer representing the amount of packets not received.
	# local loss=${pingResult%\% packet loss*} # removes everything after, and including, '% packet loss'.
	# loss=${loss##* } # removes everything before first space.

	local string="$timestamp $loss $transmitted $rx $tx" # data to be sent.

	if [ "$hasLatency" -eq 1 ]; then # if latency collecting is enabled.
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
	echo "$string" >> "$rawDataFile"; # appending string to file.
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

# sum the size $rawDataFile with the size of all compressed files inside the $compressedDataDir. if that 
# sum is bigger than number given in first argument ($1), compress that file and move it to $compressedDataDir.
zipFile() {
	local capSize="$1"

	# if file doesn't exist, we won't have to compressed anything.
	[ -f "$rawDataFile" ] || return 1 # a return of 1 means nothing has been be gzipped.

	local size=$(fileSize "$rawDataFile") # size of file with raw data.
	local dirSize=$(sumFileSizesInPath "$compressedDataDir") # sum of file sizes in directory for compressed files.

	# if sum is smaller than $capSize, do nothing.
	# echo checking file size to zip
	if [ $(($size + $dirSize)) -lt $capSize ]; then return 1; fi # a return of 1 means nothing will be gzipped.

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

	local dirSize=$(sumFileSizesInPath "$compressedDataDir") # get the sum of sizes of all files in bytes.

	# if $dirSize is more than given $capSize, remove oldest file. which is 
	# the file that shell orders as first.
	for i in "$compressedDataDir"/*; do
		[ $dirSize -lt $capSize ] && break; # if we are under $capSize. do nothing.
		rm "$i" # removes that file.
		dirSize=$(($dirSize - $(fileSize "$i"))) # subtract that file's size from sum.
	done
}

# collect every data and stores in '$rawDataFile'. if the size of the file is 
# too big, compress it and move it to a directory of compressed files. If 
# directory of compressed files grows too big delete oldest compressed files.
collectData() {
	collect_QoE_Monitor_data

	# $(zipFile) returns 0 only if any amount of files has been compressed 
	# and, consequently, moved to the directory of compressed files. So
	# $(removeOldFiles) is only executed if any new compressed file was 
	# created.
	mkdir -p "$compressedDataDir" # creates directory of for compressed files, if it doesn't already exists.
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
		lastState="$?" #return $(curl) exit code.
	fi
	# echo last state is $lastState
	return $lastState
}

# sends file at given path ($1) to server at given address ($2) using $(curl) 
# and returns $(curl) exit code.
sendToServer() {
	local filepath="$1" oldData="$2"

	local mac=$(get_mac); # defined in /usr/share/functions/device_functions.sh
	mac=${mac//:/} # removing all colons in mac address.

	status=$(curl --write-out '%{http_code}' -s -m 20 --connect-timeout 5 --output /dev/null \
	-XPOST "https://$alarmServerAddress:7890/data" -H 'Content-Encoding: gzip' \
	-H 'Content-Type: text/plain' -H "X-ANLIX-ID: $mac" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
	-H "Only-old: $oldData" --data-binary @"$filepath")
	curlCode="$?"
	[ "$curlCode" -ne 0 ] && log "DATA_COLLECTING" "Data sent with curl exit code $curlCode" && return "$curlCode"
	log "DATA_COLLECTING" "Data sent with response status code $status."
	[ "$status" -ge 200 ] && [ "$status" -lt 300 ] && return 0
	return 1
}

# for each compressed file given in $compressedDataDir, send that file to a $alarmServerAddress. 
# If any sending is unsuccessful, stops sending files and return it's exit code.
sendCompressedData() {
	# echo going to send compressed files
	# echo "$compressedDataDir"/*
	for i in "$compressedDataDir"/*; do # for each compressed file in the pattern expansion.
		# if file exists, sends file and if $(curl) exit code isn't equal to 0, returns $(curl) exit code 
		# without deleting the file we tried to send. if $(curl) exit code is equal to 0, removes file
		[ -f "$i" ] && (sendToServer "$i" "1" || return "$?") && rm "$i"
	done
	return 0
}

# compresses $rawDataFile, sends it to $alarmServerAddress and deletes it. If send was 
# successful, remove original files, if not, keeps it. Returns the return of $(curl).
sendUncompressedData() {
	# if no uncompressed file, nothing wrong, but there's nothing to do in this function.
	[ -f "$rawDataFile" ] || return 0

	# echo going to send uncompressed file
	local compressedTempFile="${rawDataFile}.gz" # the name the compressed file will have.
	# remove old file if it exists. it should never be left there.
	[ -f "$compressedTempFile" ] && rm "$compressedTempFile"

	trap "rm $compressedTempFile" SIGTERM # in case the process is interrupted, delete compressed file.
	gzip -k "$rawDataFile" # compressing to a temporary file but keeping original, uncompressed, intact.

	sendToServer "$compressedTempFile" "0" # sends compressed file.
	local sentResult="$?" # storing $(curl) exit code.

	[ "$sentResult" -eq 0 ] && rm "$rawDataFile" # if send was successful, removes original file.
	rm "$compressedTempFile" # removes temporary file. a new temporary will be created next time, with more content, 
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

# Attempts to send data some times with 10 seconds of sleep time between tries.
sendData() {
	# echo going to send data
	local tries=3 # amount of attempts of sending data, to alarm server, before giving up.

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
		[ "$currentServerState" -eq 0 ] && break # if data was sent successfully, we stop retrying.

		tries=$(($tries - 1))
		[ "$tries" -eq 0 ] && break # leaves retry loop when $retries reaches zero.
		# echo retrying in 10 seconds
		sleep 10 # sleeps before retrying. this time must take the 60 second interval into consideration.
	done
}

# echoes a random number between 0 and 59 (inclusive).
random0To59() {
	local rand=$(head /dev/urandom | tr -dc "0123456789")
	rand=${rand:0:2} # taking the first 2 digits.
	[ ${rand:0:1} = "0" ] && rand=${rand:1:2} # "08" and "09" don't work for "$(())".
	echo $(($rand * 6 / 10)) # $rand is a integer between 0 and 99 (inclusive), this makes it an integer between 0 and 59.
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
	if [ -f "$startTimeFilePath" ]; then # if file holding start time exists.
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
		sleep $(($startTime - $currentTime)) # sleep for the amount of time left to next interval.
		# this makes us always start at the same second, even if the process is shut down for a long time.
	else # if file holding start time doesn't exist.
		sleep $(random0To59); # sleeping for at most 59 seconds to distribute data collecting through a minute window.
		startTime=$(date +%s) # use current time.
	fi
	echo $startTime > "$startTimeFilePath" # substitute that time in file, or create a new file.
	echo $startTime # print start time found, or current time.
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
	local interval=60 # interval between beginnings of data collecting.
	mkdir -p "$dataCollectingDir" # making sure directory exists.
	local time=$(getStartTime "${dataCollectingDir}/startTime" $interval) # time when we will start executing.

	while true; do # infinite loop where we execute all procedures over and over again until the end of times.
		# echo startTime $time
		mkdir -p "$dataCollectingDir" # making sure directory exists every time.

		# getting FQDNs every time we need to send data, this way we don't have to 
		# restart the service if a fqdn changes.
		eval $(cat /root/flashbox_config.json | jsonfilter \
			-e "hasLatency=@.data_collecting_has_latency" \
			-e "alarmServerAddress=@.data_collecting_alarm_fqdn" \
			-e "pingServerAddress=@.data_collecting_ping_fqdn" \
			-e "pingPackets=@.data_collecting_ping_packets")
		# echo json variables: \
		# 	hasLatency="$hasLatency", alarmServerAddress="$alarmServerAddress", \
		# 	pingServerAddress="$pingServerAddress", pingPackets="$pingPackets"

		collectData # does everything related to collecting and storing data.
		sendData # does everything related to sending data and deletes data sent.

		local endTime=$(date +%s) # time after all procedures are finished.
		local timeLeftForNextRun="-1" # this will hold the time left until we should run the next iteration of this loop
		# while time left is negative, which could happen if $(($time - $endTime)) is bigger than $interval.
		while [ "$timeLeftForNextRun" -lt 0 ]; do
			time=$(($time + $interval)) # advance time, when current data collecting has started, by one interval.
			timeLeftForNextRun=$(($time - $endTime)) # calculate time left to collect data again.
		done
		# echo timeLeftForNextRun=$timeLeftForNextRun
		sleep $timeLeftForNextRun # sleep for the time remaining until next data collecting.

		# writing next loop time to file that, at this line, matches current time.
		echo $time > "${dataCollectingDir}/startTime"
	done
}

cleanFiles # deletes files, marking process state, from previous process.
loop # the infinite loop.
