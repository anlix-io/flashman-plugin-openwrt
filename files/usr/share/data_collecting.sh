#!/bin/sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/custom_wireless_driver.sh
. /usr/share/flashman_init.conf

# directory where all data related to data collecting will be stored.
dir="/tmp/data_collecting"
# file where collected data will be stored before being compressed.
rawF="${dir}/raw"
# directory where data will be stored if compressing old data is necessary.
compD="${dir}/compD"

# gets current rx and tx bytes/packets from wan interface and compares them
# with values from previous calls to calculate cross traffic
wan() {
	# checking if this data collecting is enabled

	[ $burstLoss -eq 0 ] && [ $pingAndWan -eq 0 ] && return

	# bytes received by the interface.
	local rx=$(get_wan_bytes_statistics RX)
	# bytes sent by the interface.
	local tx=$(get_wan_bytes_statistics TX)

	raw="${raw}|wanBytes $rx $tx"

	# burstLoss only gathers byte data
	[ $pingAndWan -eq 0 ] && return

	# packets received by the interface.
	local pr=$(get_wan_packets_statistics RX)
	# packets sent by the interface.
	local pt=$(get_wan_packets_statistics TX)

	# data to be sent.
	raw="${raw}|wanPkts $pr $pt"
}

# takes current unix timestamp, executes ping, in burst, to $pingServerAddress server.
# If latency collecting is enabled, extracts the individual icmp request numbers and 
# their respective ping times. Builds a string with all this information and write them to file.
burst() {
	# checking if this data collecting is enabled

	[ $burstLoss -eq 0 ] && [ $pingAndWan -eq 0 ] && return

	# burst ping with $pingPackets amount of packets.
	local p=$(ping -i 0.01 -c "$pingPackets" "$pingServerAddress")
	# ping return value.
	local e="$?"

	# if ping could not be executed, we skip this measure.
	[ "$e" -eq 2 ] && burstLoss=0 && pingAndWan=0 && return

	# An skipped measure will become missing data, for this minute, in the server.

	# removes everything behind the summary that appears in the last lines.
	local aux=${p##* ping statistics ---[$'\r\n']}
	# removes everything after, and including, ' packets transmitted'.
	local tx=${aux% packets transmitted*}
	# removes everything after, and including, ' received'.
	local rx=${aux% received*}
	# removes everything before first space.
	rx=${rx##* }
	# integer representing the amount of packets not received.
	local l=$(($tx - $rx))

	# data to be sent.
	local str="$l $tx"

	# get latency stats
	local lat=${p#*/mdev = }

	# when there is 100% packet loss there the strings remain equal
	# we only want to collect latency and std when there isn't 100% loss
	# if loss is 100% we just send 0 in both cases, which will be ignored by the server
	if [ ${#lat} == ${#p} ]; then
	    str="$str 0 0"
	else
		# latency avarage
		local la=${lat#*/}
		la=${la%%/*}

		# latency standard deviation
		local ls=${lat##*/}
		ls=${ls%% *}

		str="$str $la $ls"
	fi

	# # if latency collecting is enabled.
	# if [ "$hasLatency" -eq 1 ]; then
	# 	# echo collecting latencies
	# 	# removing the first line and the last 4 lines. only the ping lines remain.
	# 	local latencies=$(printf "%s" "$ping" | head -n -4 | sed '1d' | (
	# 	local pairs=""
	# 	local firstLine=true
	# 	# for each ping line.
	# 	while read line; do
	# 		# removes 'time=' part if it exists. if it doesn't, '$reached' will be as long as '$line'.
	# 		reached=${line%time=*}
	# 		# if "time=" has actually been removed, it means that line 
	# 		# contains it, which also means the icmp request was fulfilled.
	# 		# if line doesn't contain 'time=', we skip this line.
	# 		[ ${#reached} -lt ${#line} ] || continue

	# 		 # from the whole line, removes everything until, and including, "icmp_req=".
	# 		pingNumber=${line#*icmp_*eq=}
	# 		# removes everything after the first space.
	# 		pingNumber=${pingNumber%% *}
	# 		# from the whole line, removes everything until, and including, "time=".
	# 		pingTime=${line#*time=}
	# 		# removes everything after the first space.
	# 		pingTime=${pingTime%% *}
	# 		if [ "$firstLine" = true ]; then
	# 			firstLine=false
	# 		else
	# 			pairs="${pairs},"
	# 		fi
	# 		# concatenate to $string.
	# 		pairs="${pairs}${pingNumber}=${pingTime}"
	# 	done
	# 	# prints final $string in this sub shell back to $string.
	# 	echo $pairs))
	# 	# appending latencies to string to be sent.
	# 	[ ${#latencies} -gt 0 ] && string="${string} ${latencies}"
	# fi
	
	# appending string to file.
	# printf "string is: '%s'\n" "$string"
	raw="${raw}|burstPing $str"
}

wifi() {
	# checking if this data collecting is enabled
	[ "$wifiDevices" -eq 0 ] && return

	# devices and their data will be stored in this string variable.
	local str=""

	# flag that indicates if it's the first raw file write
	local first=1

	# 0 and 1 are the indexes for wifi interfaces: wlan0 and wlan1, or phy0 and phy1.
	for i in 0 1; do
		# getting wifi interface name.
		# 'get_root_ifname()' is defined in /usr/share/functions/custom_wireless_driver.sh.
		local w=$(get_root_ifname "$i" 2> /dev/null)
		# if interface doesn't exist, skips this iteration.
		[ -z $w ] && continue
		# getting info from each connected device on wifi. 
		# grep returns empty when no devices are connected or if interface doesn't exist.
		local iw="$(iwinfo "$w" assoclist | grep ago)"
		local pr="$(iwinfo "$w" assoclist | grep RX | grep -o '[0-9]\+ Pkts')"
		local pt="$(iwinfo "$w" assoclist | grep TX | grep -o '[0-9]\+ Pkts')"

		while [ ${#iw} -gt 0 ]; do

			# getting everything before the first space.
			local mac=${iw%% *}

			# signal.
			local s=${iw#*  }
			s=${s%% /*}
			[ "$s" == "unknown" ] && iw=${iw#*$'\n'} && continue
			s=${s%% dBm*}

			# getting after '(SNR '. 
			iw=${iw#*\(SNR }
			local snr=${iw%%\)*}
			# if SNR equals signal we assume noise of -95dBm
			[ $s -eq $snr ] && snr=$(($s+95))

			# time
			local t=${iw%% ms*}
			t=${t##* }

			# getting everything after 'ago'.
			iw=${iw#*ago}
			# getting everything after '\n', if it exists. last line won't have it, so nothing will be changed.
			# we can't add the line feed along witht the previous parameter expansion because we wouldn't match
			# the last line and so we wouldn't make $iw length become zero.
			iw=${iw#*$'\n'}

			# if $t is greater than one minute, we don't use this device's info.
			[ "$t" -gt 60000 ] && continue
			
			local rx=${pr%% *}
			pr=${pr#*$'\n'}

			local tx=${pt%% *}
			pt=${pt#*$'\n'}

			[ -z $rx ] && continue
			[ -z $tx ] && continue

			# if it's the first data we are storing, don't add a space before appending the data string.
			[ "$first" -eq 1 ] && first=0 || str="$str "
			str="${str}${i}_${mac}_${s}_${snr}_${rx}_${tx}"
		done

	done
	# only send data if there is something to send
	[ -z $str ] && wifiDevices=0 || raw="${raw}|wifiDevsStats ${str}"
}

# prints the size of a file, using 'ls', where full file path is given as 
# first argument ($1).
fSize() {
	# file size is the information at the 1st column.
	local wc=$(wc -c "$1")
	#remove suffix composed of space and anything else.
	local size=${wc% *}
	echo $size
}

# prints the sum of the sizes of all files inside given directory path.
sumSizes() {
	# boolean that marks that at least one file exists inside given directory.
	local any=0
	# for each file in that directory.
	for i in "$1"/*; do
		# if that pattern expansion exists as a file.
		[ -f "$i" ] || continue
		# set boolean to true.
		any=1
		# as we have at least one file, we don't need to loop through all files.
		break
	done
	# if no files.
	# prints zero. size of nothing is 0.
	# result was given, we can leave function.
	[ "$any" -eq 0 ] && then && echo 0 && return 0

	# if there is at least one file.

	# prints a list of sizes and files.
	local wc=$(wc -c "$1"/*)
	# if there is 2 or more files, the last line will have a "total". remove that string.
	local has=${wc% total}
	# if it has a total, it was removed. if not, nothing was removed and both strings are the same.

	# if length of string with "total" removed is smaller than original string.
	# if it has total remove everything before the last word, which is the value for total, and print what remains.
	# if there were no total, then there was only one file, in one line of output, and the first column is the size value.
	# remove everything past, and including, the first space, and print what remains.
	[ ${#has} -lt ${#wc} ] && echo ${has##* } || echo ${wc%% *}
}

# sum the size $raw with the size of all compressed files inside the $compD. if that 
# sum is bigger than number given in first argument ($1), compress that file and move it to $compD.
zip() {
	local cap="$1"

	# if file doesn't exist, we won't have to compressed anything.
	# a return of 1 means nothing has been be gzipped.
	[ -f "$rawF" ] || return 1 

	# size of file with raw data.
	local size=$(fSize "$rawF")
	# sum of file sizes in directory for compressed files.
	local dSize=$(sumSizes "$compD")

	# if sum is smaller than $cap, do nothing.
	# echo checking file size to zip
	# a return of 1 means nothing will be gzipped.
	[ $(($size + $dSize)) -lt $cap ] && return 1

	# compressing file where raw data is held.
	gzip "$rawF"
	# move newly compressed file to directory where compressed files should be.
	mv "${rawF}.gz" "$compD/$(date +%s).gz"
}

# files are removed from $compD until all data remaining is below number given in first 
# argument ($1) as bytes. As files are named using a formatted date, pattern expansion of file 
# names will always order oldest files first. This was done this way so we don't have to sort files 
# by date ourselves. we let shell do the sorting.
rmOld() {
	local cap="$1"

	# get the sum of sizes of all files in bytes.
	local dSize=$(sumSizes "$compD")

	# if $dSize is more than given $cap, remove oldest file. which is 
	# the file that shell orders as first.
	for i in "$compD"/*; do
		# if we are under $cap. do nothing.
		[ $dSize -lt $cap ] && break;
		# removes that file.
		rm "$i"
		# subtract that file's size from sum.
		dSize=$(($dSize - $(fSize "$i")))
	done
}

# collect every data and stores in '$rawF'. if the size of the file is 
# too big, compress it and move it to a directory of compressed files. If 
# directory of compressed files grows too big delete oldest compressed files.
collect() {
	# getting current unix time in seconds.
	local ts=$(date +%s)

	# global variable where current raw data is stored before being written to file.
	raw=""

	# collecting all measures.
	burst
	wan
	wifi

	# global variable that controls which measures are active
	active=""

	[ "$burstLoss" -eq 1 ] && active="${active}bl "
    [ "$wifiDevices" -eq 1 ] && active="${active}wd "
    [ "$pingAndWan" -eq 1 ] && active="${active}p&w " 
    [ ${#active} -gt 0 ] && active=${active%* }

	# mapping from measurement names to collected artifacts:
	# bl (burstLoss) -> burstPing, wanBytes
	# p&w (pingAndWan) -> burstPing, wanBytes, wanPkts
	# wd (wifiDevices) -> wifiDevsStats

	# example of an expected raw data with all measures present:
	# 'bl p&w wd|213234556456|burstPing 0 100 1.246 0.161|wanBytes 12345 1234|wanPkts 1234 123|wifiDevsStats 0_D0:9C:7A:EC:FF:FF_33_285_5136'
	[ -n "$raw" ] && [ ${#active} -gt 0 ] && echo "${active}|${ts}${raw}" >> "$rawF";
	# cleaning 'raw' value from memory.
	raw=""

	# creates directory of for compressed files, if it doesn't already exists.
	mkdir -p "$compD"
	# $(zip) returns 0 only if any amount of files has been compressed 
	# and, consequently, moved to the directory of compressed files. So
	# $(rmOld) is only executed if any new compressed file was 
	# created.
	zip $((32*1024)) && rmOld $((24*1024))
	# the difference between the cap size sent to $(zip) and 
	# $(rmOld) is the size left as a minimum amount for raw data 
	# before compressing it. This means that, if there are no compressed files, 
	# the uncompressed file could grow to as much as the cap size given to 
	# $(zip). but in case there is any amount of compressed files, the 
	# uncompressed file can grow to as much as the cap size given to $(zip) 
	# minus the sum of all the compressed files sizes. As $(rmOld) 
	# will keep the sum of all compressed files sizes to a maximum of its given 
	# cap size, the difference between these two cap sizes is the minimum size 
	# the uncompressed file will always have available for it's growth.
}

# if number given as first argument ($1) isn't 0, ping server at address given 
# in second argument ($2) and returns the exit code of $(curl), but if that 
# number is zero, return that number.
checkState() {
	local s="$1"
	if [ "$s" -ne "0" ]; then
		# echo pinging alarm server to check if it's alive.
		curl -s -m 10 "https://$alarmServerAddress:7890/ping" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" > /dev/null
		# return $(curl) exit code.
		s="$?"
	fi
	# echo last state is $s
	return $s
}

# sends file at given path ($1) to server at given address ($2) using $(curl) 
# and returns $(curl) exit code.
upload() {
	local path="$1"

	# 'get_mac()' is defined in /usr/share/functions/device_functions.sh.
	local mac=$(get_mac);

	s=$(curl --write-out '%{http_code}' -s -m 20 --connect-timeout 5 --output /dev/null \
	-XPOST "https://$alarmServerAddress:7890/data" -H 'Content-Encoding: gzip' \
	-H 'Content-Type: text/plain' -H "X-ANLIX-ID: $mac" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
	-H "Send-Time: $(date +%s)" --data-binary @"$path")
	code="$?"
	# 'log()' is defined in /usr/share/functions/common_functions.sh.
	[ "$code" -ne 0 ] && log "DATA_COLLECTING" "Data sent with curl exit code '${code}'." && return "$code"
	log "DATA_COLLECTING" "Data sent with response status code '${s}'."
	[ "$s" -ge 200 ] && [ "$s" -lt 300 ] && return 0
	return 1
}

# for each compressed file given in $compD, send that file to a $alarmServerAddress. 
# If any sending is unsuccessful, stops sending files and return it's exit code.
sendComp() {
	# echo going to send compressed files
	# echo "$compD"/*
	# for each compressed file in the pattern expansion.
	for i in "$compD"/*; do
		# if file exists, sends file and if $(curl) exit code isn't equal to 0, returns $(curl) exit code 
		# without deleting the file we tried to send. if $(curl) exit code is equal to 0, removes file
		[ -f "$i" ] && { upload "$i" || return "$?"; } && rm "$i"
	done
	return 0
}

# compresses $raw, sends it to $alarmServerAddress and deletes it. If send was 
# successful, remove original files, if not, keeps it. Returns the return of $(curl).
sendUncomp() {
	# if no uncompressed file, nothing wrong, but there's nothing to do in this function.
	[ -f "$rawF" ] || return 0

	# echo going to send uncompressed file
	# the name the compressed file will have.
	local file="${rawF}.gz"
	# remove old file if it exists. it should never be left there.
	[ -f "$file" ] && rm "$file"

	# in case the process is interrupted, delete compressed file.
	trap "rm $file" SIGTERM
	# compressing to a temporary file but keeping original, uncompressed, intact.
	gzip -k "$rawF"

	# sends compressed file.
	upload "$file"
	# storing $(curl) exit code.
	local res="$?"

	# if send was successful, removes original file.
	[ "$res" -eq 0 ] && rm "$rawF"
	# removes temporary file. a new temporary will be created next time, with more content, 
	rm "$file"
	# cleans trap.
	trap - SIGTERM

	# Returns #(curl) exit code.
	return $res
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
# 	local curState=$1 normalBackoff=$2 changedBackoff=$3 backoffCounterPath=$4
# 	if [ "$curState" -ne 0 ]; then
# 		normalBackoff=$changedBackoff
# 	fi
# 	# echo writting backoff.
# 	echo $normalBackoff > "$backoffCounterPath"
# }

# Attempts to send data some times with 10 seconds of sleep time between tries.
send() {
	# echo going to send data
	# amount of attempts of sending data, to alarm server, before giving up.
	local tries=3

	while true; do
		# check if the last time, data was sent, server was alive. if it was, 
		# send compressed data, if everything was sent, send uncompressed 
		# data. If server wasn't alive last time, ping it and if it's alive 
		# now, then send all data, but if it's still dead, do nothing.
		local stateF="$dir/state"
		local last="1"
		[ -f "$stateF" ] && last=$(cat "$stateF")
		# echo state=$state

		checkState "$last" && sendComp && sendUncomp
		local cur="$?"
		# echo cur=$cur
		# if server stops before sending some data, current server state will differ from last server state.
		# $cur get the exit code of the first of these 3 functions above that returns anything other than 0.

		# writes the $(curl) exit code if it has changed since last attempt to send data.
		[ "$cur" -ne "$last" ] && echo "$cur" > "$stateF"
		# if data was sent successfully, we stop retrying.
		[ "$cur" -eq 0 ] && break

		tries=$(($tries - 1))
		# leaves retry loop when $retries reaches zero.
		[ "$tries" -eq 0 ] && break
		# echo retrying in 10 seconds
		# sleeps before retrying. this time must take the 60 second interval into consideration.
		sleep 10
	done
}

# echoes a random number between 0 and 59 (inclusive).
rand0To59() {
	local r=$(head /dev/urandom | tr -dc "0123456789")
	# taking the first 2 digits.
	r=${r:0:2}
	# "08" and "09" don't work for "$(())".
	[ ${r:0:1} = "0" ] && r=${r:1:2}
	# $r is a integer between 0 and 99 (inclusive), this makes it an integer between 0 and 59.
	echo $(($r * 6 / 10))
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
start() {
	local file="$1" int="$2"

	local start
	# if file holding start time exists.
	if [ -f "$file" ]; then
		local cur=$(date +%s)
		start=$(cat "$file") # get the time stamp inside that file.
		# advance timestamp to the closest time after current time that the given interval could produce.
		start=$(($start + (($cur - $start) / $int) * $int + $int))
		# that division does not produce a float number. ex: (7/2)*2 = 6.
		# $start + (($cur - $start) / $int) * $int 
		# results in the closest time to $cur that $int could 
		# produce, starting from $start, that is smaller than $cur. 
		# By adding $int, we get the closest time to $cur that 
		# $int could produce that is bigger than $currentTtime.
		# sleep for the amount of time left to next interval.
		sleep $(($start - $cur))
		# this makes us always start at the same second, even if the process is shut down for a long time.
	else 
		# if file holding start time doesn't exist.
		# sleeping for at most 59 seconds to distribute data collecting through a minute window.
		sleep $(rand0To59)
		# use current time.
		start=$(date +%s)
	fi
	# substitute that time in file, or create a new file.
	echo $start > "$file"
	# print start time found, or current time.
	echo $start
}

# deletes files, marking process state, from previous process and deletes temporary
# files that could be hanging if process is terminated in a critical part.
clean() {
	rm "${dir}/state" 2> /dev/null
	# rm "${dir}/backoffCounter" 2> /dev/null
	rm "${rawF}.gz" 2> /dev/null
}

# collects and sends data forever.
loop() {
	# interval between beginnings of data collecting.
	local int=60
	# making sure directory exists.
	mkdir -p "$dir"
	# time when we will start executing.
	local time=$(start "${dir}/startTime" $int)

	# infinite loop where we execute all procedures over and over again until the end of times.
	while true; do
		# echo startTime $time
		# making sure directory exists every time.
		mkdir -p "$dir"

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
		collect
		# does everything related to sending data and deletes data sent.
		send

		# time after all procedures are finished.
		local end=$(date +%s)
		# this will hold the time left until we should run the next iteration of this loop
		local delta="-1"
		# while time left is negative, which could happen if $(($time - $end)) is bigger than $int.
		while [ "$delta" -lt 0 ]; do
			# advance time, when current data collecting has started, by one interval.
			time=$(($time + $int))
			# calculate time left to collect data again.
			delta=$(($time - $end))
		done
		# echo delta=$delta
		 # sleep for the time remaining until next data collecting.
		sleep $delta

		# writing next loop time to file that, at this line, matches current time.
		echo $time > "${dir}/startTime"
	done
}

# deletes files, marking process state, from previous process.
clean
# the infinite loop.
loop
