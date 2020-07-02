#!/bin/sh
. /usr/share/functions/device_functions.sh
. /usr/share/flashman_init.conf

influxDataDir="/tmp/influx_data_collecting"
influxRawDataDir=$influxDataDir"/raw"
influxCompressedDataDir=$influxDataDir"/compressed"
# $influxDBAddress is inside /usr/share/flashman_init.conf, it holds the ip to influxdb.

# prints the name of all available wireless interfaces, separated by new lines.
getAllInterfaceNames() {
	local index=0 name
	while true; do
		name=$(uci -q get wireless.default_radio$index.ifname)
		if [ "$?" -ne 0 ]; then break; fi
		echo $name
		index=$(($index + 1))
	done
}

# prints the size of a file, using 'ls', where full file 
# path is given as first argument ($1).
fileSize() {
	local wcline=$(wc -c "$1") # file size is the information at the 1th column.
	local size=${wcline% *} #remove suffix: space and anything else.
	echo $size
}

# prints the sum of the sizes of all files which paths are 
# given separated by space or new line given in first argument ($1).
sumFileSizes() {
	local sumSize=0
	for i in $1; do # for each file path.
		[ -f "$i" ] || continue
		sumSize=$(($sumSize + $(fileSize $i))) # increment 'sumSize' by its size.
	done
	echo $sumSize
}

# sum the sizes of all files which paths are given in first argument ($1). if 
# that sum is bigger than number given in second argument ($2), join the 
# contents of all these files in a final file which full path is given by 
# third argument ($3), gzip it and delete each original file.
zipFiles() {
	local filesPaths="$1" capSize=$2 zippedFilePath=$3

	local sumSize=$(sumFileSizes "$filesPaths")
	# echo zipping files found "sumSize=$sumSize"
	if [ $sumSize -lt $capSize ]; then return 1; fi # a return of 1 means nothing will be gzipped.

	mkdir -p ${zippedFilePath%/*} # mkdir with the directory the final file should be in.
	for i in $filesPaths; do # for each given file.
		[ -f "$i" ] || continue
		cat "$i" >> "$zippedFilePath" # append to end of final file.
		rm "$i" # remove file.
	done
	gzip "$zippedFilePath" # gzip final file.
}

# given file paths in first argument ($1), starting from first to last, files 
# are removed until all data remaining is below number given in second 
# argument ($2). As files are named using a formatted date, pattern expansion 
# of file names will always order oldest files first. This was done this way 
# so we don't have to sort files by date ourselves. we let shell do the 
# sorting.
removeOldFiles() {
	local filesPaths=$1 capSize=$2=

	local sumSize=$(sumFileSizes "$filesPaths")

	# if $sumSize is more than given $capSize, remove oldest file. which is 
	# the file that shell orders as first.
	for i in $filesPaths; do
		# echo removing files found "sumSize=$sumSize"
		if [ $sumSize -lt $capSize ]; then break; fi;
		sumSize=$(($sumSize - $(fileSize "$i"))) # subtract that file's size from sum.
		rm "$i" # remove that file.
		# echo removed file "$i"
		# echo new sumSize is $sumSize
	done
}


# extract data from devices in wifi, builds a string in influx line protocol 
# format, which uses the router's mac address ($2) to identify the router 
# each device belongs to, and append that string to file given as first 
# argument ($1).
collectDevicesWifiDataForInflux() {
	local filename="$1" mac="$2"

	local timestamp=$(date +%s) # getting current unix time in seconds.
	local allDevices oneDevice snr

	for interface in $(getAllInterfaceNames); do # for each interface in the router;
		# extracting the signal to noise ratio value from the interface.
		snr=$(iwinfo ${interface} assoclist) # interface info where we will take the snr value.
		snr=${snr#*\(SNR } # removes everything until "(SNR " including it.
		snr=${snr%%\)*} # removes everything past "\)" including it.

		allDevices=$(iw dev ${interface} station dump); # this prints only if there is any device connected to wifi.
		while [ "$allDevices" ]; do
			oneDevice=${allDevices##*Station }; # removes, from $allDevices, the biggest match before and including "Station ".
			allDevices=${allDevices%Station *}; # removes, from $allDevices, the smallest match after and including "Station ".

			# following command extract fields from one device and builds a 
			# string as influx line protocol format and append that to a file.
			echo $oneDevice | sed "
			s/\([0-9a-f:]*\).* rx bytes: \([0-9]*\).*rx packets: \([0-9]*\).*tx bytes: \([0-9]*\).*tx packets: \([0-9]*\).*signal:\s*\([-0-9]*\)\s.*dBm.*tx bitrate: \([0-9]*\.[0-9]*\).*rx bitrate: \([0-9]*\.[0-9]*\).*/wifi,d=\1,r=${mac} rx=\8,rxb=\2i,rxp=\3i,sig=\6i,snr=${snr},tx=\7,txb=\4i,txp=\5i ${timestamp}/
			s/://g" >> "$filename"; # file name is the timestamp, this helps to order the files by creation time.
		done
	done
}

# gets wan info from /sys/class/net/$wanName/statistics/ and builds a string 
# in influx line protocol format, which uses the router's mac address, given 
# as second argument ($2), to identify the router, and append that string to 
# file given as first argument ($1).
collectWanStatisticsForInflux() {
	local filename="$1" mac="$2"

	local timestamp=$(date +%s) # getting current unix time in seconds.
	local wanName=$(uci get network.wan.ifname) # name of the wan interface.
	local rxBytes=$(cat /sys/class/net/$wanName/statistics/rx_bytes)
	local txBytes=$(cat /sys/class/net/$wanName/statistics/tx_bytes)
	local rxPackets=$(cat /sys/class/net/$wanName/statistics/rx_packets)
	local txPackets=$(cat /sys/class/net/$wanName/statistics/tx_packets)
	local string="wan,r=$mac rxb=${rxBytes}i,rxp=${rxPackets}i,txb=${txBytes}i,txp=${txPackets}i $timestamp"
	# echo s$string
	echo "$string" > "$filename"
}

# executes 100 pings, in burst, to flashman server, extracts the individual 
# icmp request number and its respective ping time and builds a string in
# influx line protocol format, which uses the router's mac address, given 
# as second argument ($2), to identify the router, and append that string 
# to file given as first argument ($1).
collectPingForInflux() {
	local filename="$1" mac="$2"

	local timestamp=$(date +%s) # getting current unix time in seconds.
	local string="ping,r=$mac " # beginning of influx line protocol string.
	local pingNumber pingTime unreachable

	local pingResult=$(ping -i 0.01 -c 100 "$FLM_SVADDR") # 100 pings in burst.
	local pingSummary=${pingResult##* ---} # the summary that appears in the last lines.

	# as numerical characters are small than letters, the icmp request numbers 
	# are written first to string, then the letters charactered fields are 
	# written.

	# removing the first line and the last 4 lines. only the ping lines remain.
	string=$(printf "%s" "$pingResult" | head -n -4 | sed '1d' | (while read line; do # for each ping line.
		unreachable=${line% Unreachable} # removes ' Unreachable' part if it exists.
		# if " Unreachable" has actually been removed, it means that line 
		# contains it, which also means that icmp request wasn't fulfilled. 
		[ ${#unreachable} -eq ${#line} ] || continue # if line contains ' Unreachable', skip this line.

		pingNumber=${line#*icmp_req=} # from the whole line, removes everything until, and including, "icmp_req=".
		pingNumber=${pingNumber%% *} # removes everything after the first space.
		pingTime=${line#*time=} # from the whole line, removes everything until, and including, "time=".
		pingTime=${pingTime%% *} # removes everything after the first space.
		string="${string}$pingNumber=$pingTime," # concatenate to $string.
	done
	echo $string)) # prints final $string in this sub shell back to $string.

	local loss=${pingSummary%\% packet loss*} # removes everything after, and including, '% packet loss'.
	loss=${loss##* } # removes everything after first space.
	if [ $loss -ne 100 ]; then # if $loss is not '100'.
		local average=${pingSummary#*[0-9]/} # takes average after removing everything until, and including first digit followed by '/'.
		average=${average%%/*} # removes everything after first '/'.
		string="${string}avg=$average," # append average information.
	fi # when loss is 100%, no rtt information is present in ping result, which means there is no average, min or max info.
	string="${string}loss=${loss}i ${timestamp}" # append loss information and $timestamp to string.

	# printf "string is: '%s'\n" "$string"
	echo "$string" > "$filename" # appending string to file.
}

# collect every data and stores in a file which name is the time when the 
# script ran, given as first argument ($1), in a directory for uncompressed 
# files. if the size of the files is this directory is too big, join all files 
# in a new file in a directory for compressed files and compress it.
collectData() {
	local time="$1"

	# getting routers mac address used to identify the router.
	local mac=$(get_mac); # defined in /usr/share/functions/device_functions.sh
	mac=${mac//:/} # removing all colons in mac address.
	mkdir -p "$influxRawDataDir" # if 'dataPath' doesn't exists, create it and all parent directories.
	local file="${influxRawDataDir}/$time"

	collectDevicesWifiDataForInflux "$file" "$mac"
	collectWanStatisticsForInflux "$file" "$mac"
	collectPingForInflux "$file" "$mac"

	# $(zipFiles) returns 0 only if any amount of files has been compressed 
	# and, consequently, moved to the directory of compressed files. So
	# $(removeOldFiles) is only execute if any new compressed file was 
	# created.
	zipFiles "$influxRawDataDir/*" 6144 "$influxCompressedDataDir/wifi_"$(date +"%FT%H-%M-%S") && \
	removeOldFiles "$influxCompressedDataDir/*" 2048
}


# prints the number written in the file at given path ($1) if it exists, 
# else prints 1.
getLastServerState() {
	local lastServerStateFilePath="$1" # file that holds the last $(curl) exit code made to server.
	local lastState
	if [ -f "$lastServerStateFilePath" ]; then # if file exists.
		echo $(cat "$lastServerStateFilePath")
	else
		echo 1
	fi
}

# if number given as first argument ($1) isn't 0, ping influx at address given 
# in second argument ($2) and returns the exit code of $(curl), but if that 
# number is zero, return that number.
checkLastServerState() {
	local lastState=$1 serverAddress=$2
	if [ $lastState -ne 0 ]; then
		echo pinging influx
		curl -sl -I "http://$serverAddress:8086/ping" > /dev/null # check if server is alive.
		lastState="$?" #return $(curl) exit code.
		# echo ping found state $currentState
	fi
	return $lastState
}

# if first argument ($1) isn't equal 0, write it to a file at path given in 
# second argument ($2).
writeCurrentServerState() {
	local currentState=$1 lastState=$2 serverStateFilePath="$3"
	echo current influx state is $currentState and last state $lastState
	if [ $currentState -ne $lastState ]; then # if server state has changed.
		echo writing current server state $currentState
		echo $currentState > "$serverStateFilePath" # write server state to file.
	fi
}

# sends file at given path ($1) to influxdb at given address ($2) using $(curl) 
# and returns $(curl) exit code.
sendToInflux() {
	local filepath="$1" serverAddress=$2
	echo sending curl
	curl -s -m 20 --connect-timeout 5 \
	-XPOST "http://$serverAddress:8086/write?db=stress&precision=s" \
	-H 'Content-Encoding: gzip' \
	-H 'Content-Type: application/octet-stream' \
	--data-binary @"$1"
	return "$?"
}

# for each compressed file given in first argument ($1), send that file to a 
# server at address given in second argument ($2). If any sending is 
# unsuccessful, stop sending and return it's last exit code;
sendCompressedData() {
	local compressedFilesPaths="$1" serverAddress="$2"

	# echo going to send compressed data
	# echo $compressedFilesPaths

	local sentResult
	for i in $compressedFilesPaths; do # for each compressed file in the pattern expansion.
		# echo checking existence of file $i
		[ -f "$i" ] || continue # check if file still exists.
		# echo sending file $i
		sendToInflux "$i" $serverAddress # se file to influx.
		sentResult="$?" # store $(curl) exit code.
		if [ "$sentResult" -eq 0 ]; then # if $(curl) exit code is equal to 0.
			# echo finished sending, now removing.
			rm "$i" # remove file.
		else # but if $(curl) exit code isn't equal to 0.
			# echo could not send.
			return "$sentResult" # return $(curl) exit code without deleting the file we tried to send.
		fi
	done
}

# for each uncompressed file given in first argument ($1), append their 
# content to a new file at path given in second argument ($2). Then, compress 
# it and send it to a server at address given in third argument ($3) and 
# delete it. If send was successful, remove original files, if not, keep them. 
# Returns the return of $(curl).
sendUncompressedData() {
	local uncompressedFilesPaths="$1" tempFilePath="$2" serverAddress="$3"

	# echo going to send uncompressed files
	
	mkdir -p ${tempFilePath%/*} # mkdir with the directory the temp file should be in.
	for i in $uncompressedFilesPaths; do # for each uncompressed file in the pattern expansion.
		[ -f "$i" ] || continue # check if file still exists.
		# echo appending $i to final file
		cat $i >> "$tempFilePath" # append it's content to the temporary file.
	done
	# echo compressing final files
	local compressedTempFilePath="${tempFilePath}.gz" # the name the compressed file will have.
	trap "rm $compressedTempFilePath" SIGTERM # in case the process is interrupted, delete compressed file.
	gzip "$tempFilePath" # compress temporary file.

	# echo sending compressed final file
	sendToInflux "$compressedTempFilePath" $serverAddress # send compressed file to influx.
	local sentResult="$?" # store $(curl) exit code.
	rm "$compressedTempFilePath" # remove temporary file. a new temporary should be created, with more content, if we couldn't send data this time.
	trap - SIGTERM # clean trap
	# echo removed compressed final file

	if [ "$sentResult" -eq 0 ]; then # if send was successful
		# echo removing uncompressed files
		rm $uncompressedFilesPaths # remove original files.
	fi
	return $sentResult # Returns #(curl) exit code.
}

checkBackoff() {
	local backoffCounterPath=$1 minBackoffCounter=$2
	local counter
	if [ -f  "$backoffCounterPath" ]; then
		counter=$(cat "$backoffCounterPath")
	else
		counter=$minBackoffCounter
	fi
	counter=$((counter - 1))
	# echo new backoff is $counter
	if [ $counter -ne 0 ]; then
		echo $counter > "$backoffCounterPath"
		return 1 # return 1 means we remain in backoff.
	fi
}

# given an exit code as first argument ($1), if it's 0, the second argument 
# ($2) is written to file at path given in forth argument (4), but if it's not 
# 0, the third argument ($3) is written instead.
writeBackoff() {
	local currentServerState=$1 normalBackoff=$2 changedBackoff=$3 backoffCounterPath=$4
	if [ "$currentServerState" -ne 0 ]; then
		normalBackoff=$changedBackoff
	fi
	# echo writting backoff $normalBackoff
	echo $normalBackoff > "$backoffCounterPath"
}


# prints a number between 1 and 9.
random1To9() {
	local _rand=$(head /dev/urandom | tr -dc "123456789")
	echo ${_rand:0:1}
}

# check if it's time to send data, check if last time that data was sent the 
# server was alive and then send all compressed files and all uncompressed 
# files. if everything went ok, it will only send data again after as many 
# calls, to this function, as $defaultBackoff.
sendData() {
	local defaultBackOff=5 # amount of calls needed to trigger the sending of data.

	# check if we will send data this time and returns 0 if true. this controls if we will send data at this call.
	checkBackoff "${influxDataDir}/backoffCounter" $defaultBackOff
	if [ "$?" -eq 0 ]; then # if $(checkBackoff) returned 0.

		# check if the last time, data was sent, server was alive. if it was, 
		# send compressed data, if everything was sent, send uncompressed 
		# data. If server wasn't alive last time, ping it and if it's alive 
		# now, then send all data, but if it's still dead, do nothing.
		local lastServerState=$(getLastServerState "$influxDataDir/serverState")
		checkLastServerState "$lastServerState" $influxDBAddress && \
		sendCompressedData "${influxCompressedDataDir}/*.gz" $influxDBAddress && \
		sendUncompressedData "${influxRawDataDir}/*" "${influxDataDir}/latestdata" $influxDBAddress
		local currentServerState="$?"
		# if server stops before sending some data, current server state will differ from last server state.
		# $currentServerState get the exit code of the first of these 3 functions above that returns anything other than 0.

		# writes the $(curl) exit code if has changed since last attempt to send data.
		writeCurrentServerState $currentServerState $lastServerState "$influxDataDir/serverState"
		# sets a random backoff if $(curl) exit code wasn't equal 0.
		writeBackoff $currentServerState $defaultBackOff $((1 + $(random1To9))) "${influxDataDir}/backoffCounter"
	fi
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
		startTime=$(( $startTime + (($currentTime - $startTime) / $interval) * $interval + $interval))
		# that division does not produce a float number. ex: (7/2)*2 = 6.
		# $startTime + (($currentTime - $startTime) / $interval) * $interval 
		# results in the closest time to $currentTtime that $interval could 
		# produce, starting from $startTime, that is smaller than $currentTime. 
		# By adding $interval, we get the closest time to $currentTtime that 
		# $interval could produce that is bigger than $currentTtime.
		sleep $(($startTime - $currentTime)) # sleep for the amount of time left to next interval.
		# this makes us always start at the same second, even if the process is shut down for a long time.
	else # if file holding start time doesn't exist.
		startTime=$currentTime # use current time.
	fi
	echo $startTime > $startTimeFilePath # substitute that time in file, or create a new file.
	echo $startTime # print start time found, or current time.
}

loop() {
	local interval=5 # interval between beginnings of data collecting.
	local time=$(getStartTime "$influxDataDir/startTime" $interval) # time when we will start executing.
	while true; do # infinite loop where we execute all procedures over and over again until the end of times.
		echo startTime $time

		collectData "$time" # does everything related to collecting and storing data.
		sendData # does everything related to sending data and deletes data sent.

		local endTime=$(date +%s) # time after all procedures are finished.
		local timeLeftForNextRun="-1" # this will hold the time left until we should run the next iteration of this loop
		# while time left is negative, which could happen if $(($time - $endTime)) is bigger than $interval.
		while [ $timeLeftForNextRun -lt 0 ]; do
			time=$((time + $interval)) # advance time when current data collecting has started by one interval.
			timeLeftForNextRun=$(($time - $endTime)) # calculate time left to next data collecting.
		done
		sleep $timeLeftForNextRun # sleep for the time remaining until next data collecting.
	done
}

# loop