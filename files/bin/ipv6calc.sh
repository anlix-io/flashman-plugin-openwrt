#!/bin/sh

awk -f - $* <<EOF

# Converts and ipv6 to integer
function ipv62intv2(ipv6, octets) {

	n=split(ipv6, aux, ":")
	in1=1
	
	for (in2 = 1; in2 <= n; in2++) {
		len=length(aux[in2])
		
		if (len == 0) {
			# Values to be done + missing values + values already done = 8 octets
			# (the lenght of array - the index of source) + 
			# the index of the target = 8 octets
			# ((n - 1) - (in2 - 1)) + (in1 - 1) = 8
			towalk = 8 - (n - in2 - 2) - in1 - 1
		
			for (x=0; x<towalk; x++) {
				octets[in1 + x] = "0x0"
			}
			
			in1=in1 + towalk - 1
		} else {
			octets[in1] = "0x" aux[in2]
		}
		
		in1++
	}
}


# Calculates the new ipv6 with the mask passed
# ipv6 - The ipv6 as integer
# mask - The mask value
function ipv6mask(octets, mask, ipv6) {
	for (i in octets) {
		if (mask > 0) {
			x = 16 - mask
			ipv6[i] = and(strtonum(octets[i]), lshift(0xffff, (mask >= 16) ? 0 : x))
			mask = -x
		} else {
			ipv6[i] = 0
		}
	}
}


# Prints the ipv6
function printipv6(ipv6) {
	string = sprintf("%x", ipv6[1])
	len = length(ipv6)
	zero = 0
	for (i = 2; i <= len; i++) {
		if (ipv6[i] == 0 && i < len && ipv6[i+1] == 0) {
			string = zero ? string : string ":"
			zero = 1
		} else if (ipv6[i-1] != 0 || ipv6[i] != 0) {
			string = sprintf("%s:%x", string, ipv6[i])
			zero = 0
		}
	}
	
	string = zero ? string ":" : string
	print string
}


BEGIN {
	n=split(ARGV[1], ipmask, "/")
	if (n == 2) {
		ipv62intv2(ipmask[1], octets)
		ipv6mask(octets, ipmask[2], ipv6)
		printipv6(ipv6)
	} else {
		ipv62intv2(ARGV[1], octets)
		ipv6mask(octets, ARGV[2], ipv6)
		printipv6(ipv6)
	}
}
EOF
