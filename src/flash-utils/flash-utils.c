#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "constants.h"
#include "types.h"


#define CHECK_AND_COPY_FIELD(field, field_size)						\
	if(!strncmp(param, #field, strlen(#field))) {					\
		error_or_parameter.error = OK;								\
		error_or_parameter.size = field_size;						\
																	\
		memcpy(	&error_or_parameter.value, 							\
				&(mib->wlan_mib[interface].field), 					\
				field_size 											\
			);														\
																	\
		return error_or_parameter;									\
	}


/*
 *	Description: Prints the usage of this tool
 *
 * 	Inputs:
 * 		program_name:	char*	- The name of this tool
 *
 */
void print_usage(char *program_name) {
	printf("Usage: %s [INTERFACE] [PARAMETER] [INTERFACE] [PARAMETER] ...\n", program_name);
	printf("Extracts parameters from MTD configuration partition (%s).\n\n", MTD_CONFIGURATION_LOCATION);
	printf("Max interface number: %d\n", NUM_WLAN_INTERFACE);
	printf("Interface 1: 5G\n");
	printf("Interface 2: 2.4G\n\n");

	printf("\t--help\tShows this help and exit.\n");
}


/*
 *	Description: Prints the hex of mib like hexdump
 *
 * 	Inputs:
 * 		mib:	realtek_mib	- The mib to dump
 * 		start:	size_t		- The start position of the mib to dump
 * 		end:	size_t		- The last  position of the mib to dump
 *
 */
void hexdump(realtek_mib mib, size_t start, size_t end) {
	int bytes = start;

	// If end = 0 print everything
	while (bytes < sizeof(realtek_mib) && ((end == 0) || (bytes < end))) {

		if ((bytes - start) % 16 == 0)
			printf("\n%08X  ", bytes);

		if ((bytes - start) % 8 == 0 && (bytes - start) % 16 != 0)
			printf(" ");

		printf("%02X ", (unsigned char) mib.signature[bytes]);

		bytes++;

	}

	printf("\n\n");
}


/*
 *	Description: Prints the power diff for 5G interfaces
 *	that has MAX_5G_DIFF_NUM size
 *
 * 	Inputs:
 * 		power_diff:	char	- Array to the parameter to print
 *
 */
void print_power_diff (const unsigned char power_diff[]) {

	/* 
	 * The idea of power diff cells for 5G is to be based
	 * in the 40MHz channels. It starts at the channel 36,
	 * goes up to 64, starts again at 100 and does up to
	 * channel 177.
	 * 
	 * So, we have the following prints based on the 14
	 * numbers:
	 * 
	 * Meaning				Channels
	 * XX - 35 Zeros		(01 - 35)
	 * 01 - 5 Power Diffs 	(36 - 40)
	 * 02 - 8 Power Diffs 	(44 - 48)
	 * 03 - 8 Power Diffs	(52 - 56)
	 * 04 - 8 Power Diffs	(60 - 64)
	 * XX - 35 Zeros		(65 - 99)
	 * 05 - 5 Power Diffs	(100 - 104)
	 * 06 - 8 Power Diffs	(108 - 112)
	 * 07 - 8 Power Diffs	(116 - 120)
	 * 08 - 8 Power Diffs	(124 - 128)
	 * 09 - 8 Power Diffs	(132 - 136)
	 * 10 - 8 Power Diffs	(140 - 144)
	 * 11 - 9 Power Diffs	(149 - 153)
	 * 12 - 8 Power Diffs	(157 - 161)
	 * 13 - 8 Power Diffs	(165 - 169)
	 * 14 - 8 Power Diffs	(173 - 177)
	 * XX - 19 Zeros		(178 - 196)
	 * 
	 */

	unsigned int cell, prints;

	// Iterate every position of array
	for (cell = 0; cell < MAX_5G_DIFF_NUM; cell++) {

		// Fill with zeros
		if (cell == 0 || cell == 4){

			for (prints = 0; prints < 35; prints++)
				printf("00");

		}

		for (prints = 0; prints < CHANNEL_SIZES[cell]; prints++)
			printf("%02X", (unsigned int) power_diff[cell]);

	}

	// Print last zeros
	for (prints = 0; prints < 19; prints++)
		printf("00");
	
	printf(" ");

}


/*
 *	Description: Reads the MTD configuration partition
 *
 *
 *	Outputs:
 *		result_mib				- The error or the mib extracted
 */
result_mib read_mtd() {

	// Variable that stores the error or the mib
	result_mib error_or_mib;
	int error;

	// Sets the error to OK
	error_or_mib.error = OK;


	// Open the MTD
	FILE *file = fopen(MTD_CONFIGURATION_LOCATION, "rb");

	// Check if file opened successfully
	if (file == NULL) {

		error_or_mib.error = FILE_NOT_OPENED;
		error_or_mib.error_string = strerror(errno);

		return error_or_mib;
	}


	// Allocate the buffer and read it
	char buffer[sizeof(realtek_mib) + 11]; // Add a safeguard to not overflow
	int bytes_read = 0, total_bytes = 0;

	do {

		bytes_read = fread(&buffer[total_bytes], sizeof(unsigned char), BYTES_TO_READ, file);

		if (bytes_read > 0)
			total_bytes += bytes_read;

	} while (bytes_read > 0 && bytes_read == BYTES_TO_READ && total_bytes < sizeof(realtek_mib));


	// Error at reading file
	if (ferror(file)) {

		error_or_mib.error = FILE_NOT_READ;
		error_or_mib.error_string = strerror(errno);
	}

	// Invalid partition signature
	else if(strncmp((char *) &buffer, MTD_PARTITION_SIGNATURE, strlen(MTD_PARTITION_SIGNATURE))) {
		error_or_mib.error = INVALID_PARTITION;
		error_or_mib.error_string = INVALID_PARTITION_STRING;
	}

	// Copy the mib
	else
		memcpy(&error_or_mib.mib, buffer, sizeof(realtek_mib));


	// Close the file
	error = fclose(file);

	// Error while trying to close the file
	if (error != 0) {

		error_or_mib.error = FILE_NOT_CLOSED;
		error_or_mib.error_string = FILE_NOT_CLOSED_STRING;
	}


	return error_or_mib;
}


/*
 *	Description: Returns the value of a parameter in the mib
 *
 * 	Inputs:
 * 		mib:		realtek_mib*	- Pointer to the mib to extract the value
 * 		param:		char*			- String of the parameter
 * 		interface:	short			- The number of the interface
 * 		
 *
 *	Outputs:
 *		result_mib_value			- The error or the value extracted and the size
 */
result_mib_value get_mib_parameter(const realtek_mib* mib, const char* param, unsigned short interface) {

	// Variable that stores the error or the pointer to the value
	result_mib_value error_or_parameter;


	// Check if pointers are valid
	if (mib == NULL || param == NULL) {
		error_or_parameter.error = NULL_POINTER;
		error_or_parameter.error_string = NULL_POINTER_STRING;
		
		return error_or_parameter;
	}

	
	// If the interface is bigger then the number of interfaces
	// As long it is unsigned, the 0 shall not be the problem
	if (interface < 0 || interface > NUM_WLAN_INTERFACE) {
		error_or_parameter.error = INVALID_INTERFACE;
		error_or_parameter.error_string = INVALID_INTERFACE_STRING;
		
		return error_or_parameter;
	}


	// Sets the error to not found
	error_or_parameter.error = ENTRY_NOT_FOUND;
	error_or_parameter.error_string = ENTRY_NOT_FOUND_STRING;


	// Check every parameter
	if(!strncmp(param, "mac_address", strlen("mac_address"))) {

		error_or_parameter.error = OK;
		error_or_parameter.size = MAC_ADDRESS_SIZE * sizeof(unsigned char);

		// Verify the last digit of mac addres
		switch (param[strlen("mac_address")])
		{
		case '1':
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address1), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;

		case '2':
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address2), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;

		case '3':
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address3), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;

		case '4':
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address4), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;

		case '5':
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address5), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;

		case '6':
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address6), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;

		case '7':
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address7), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;

		case '8':
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address8), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;
		
		// Maybe it didn't come with the number
		default:
			memcpy(	&error_or_parameter.value, 
					&(mib->wlan_mib[interface].mac_address1), 
					MAC_ADDRESS_SIZE * sizeof(unsigned char)
				);
			break;
		}

		return error_or_parameter;
	}

	CHECK_AND_COPY_FIELD(power_level_cck_a, 				MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(power_level_cck_b, 				MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(power_level_ht40_1s_a, 			MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(power_level_ht40_1s_b, 			MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(power_diff_ht40_2s,				MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(power_diff_ht20, 					MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(power_diff_ofdm, 					MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	
	CHECK_AND_COPY_FIELD(reg_domain, 						sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(rf_type, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(led_type, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(x_cap, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tssi1, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tssi2, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(thermal, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tr_switch, 						sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tr_swpape_c9, 						sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tr_swpape_cc, 						sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(target_power, 						sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(pa_type, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(thermal2, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(thermal3, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(thermal4, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(x_cap2, 							sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(kfree_enable, 						sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(reserved9, 						sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(reserved10, 						sizeof(unsigned char))
	
	CHECK_AND_COPY_FIELD(tx_power_5g_ht40_1s_a, 			MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_5g_ht40_1s_b, 			MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_ht40_2s, 			MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_ht20, 			MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_ofdm,				MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	
	CHECK_AND_COPY_FIELD(tx_power_tssi_cck_a, 				MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_cck_b, 				MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_cck_c, 				MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_cck_d, 				MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))

	CHECK_AND_COPY_FIELD(tx_power_tssi_ht40_1s_a, 			MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_ht40_1s_b, 			MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_ht40_1s_c, 			MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_ht40_1s_d, 			MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))

	CHECK_AND_COPY_FIELD(tx_power_tssi_5g_ht40_1s_a, 		MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_5g_ht40_1s_b, 		MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_5g_ht40_1s_c, 		MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_tssi_5g_ht40_1s_d, 		MAX_5G_CHANNEL_NUM_MIB * sizeof(unsigned char))

	CHECK_AND_COPY_FIELD(tssi_enable, 						sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(wsc_pin, 							9 * sizeof(unsigned char))

	CHECK_AND_COPY_FIELD(tx_power_diff_20bw1s_ofdm1t_a, 	MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_40bw2s_20bw2s_a, 	MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_ofdm2t_cck2t_a, 		MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_40bw3s_20bw3s_a, 	MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_ofdm3t_cck3t_a, 		MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_40bw4s_20bw4s_a, 	MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_ofdm4t_cck4t_a, 		MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))

	CHECK_AND_COPY_FIELD(tx_power_diff_5g_20bw1s_ofdm1t_a, 	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_40bw2s_20bw2s_a,	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_40bw3s_20bw3s_a, 	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_40bw4s_20bw4s_a,	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_rsvd_ofdm4t_a, 	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_80bw1s_160bw1s_a,	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_80bw2s_160bw2s_a, MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_80bw3s_160bw3s_a,	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_80bw4s_160bw4s_a,	MAX_5G_DIFF_NUM * sizeof(unsigned char))

	CHECK_AND_COPY_FIELD(tx_power_diff_20bw1s_ofdm1t_b, 	MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_40bw2s_20bw2s_b, 	MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_ofdm2t_cck2t_b, 		MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_40bw3s_20bw3s_b, 	MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_ofdm3t_cck3t_b, 		MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_40bw4s_20bw4s_b, 	MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_ofdm4t_cck4t_b, 		MAX_2G_CHANNEL_NUM_MIB * sizeof(unsigned char))

	CHECK_AND_COPY_FIELD(tx_power_diff_5g_20bw1s_ofdm1t_b, 	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_40bw2s_20bw2s_b,	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_40bw3s_20bw3s_b, 	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_40bw4s_20bw4s_b,	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_rsvd_ofdm4t_b, 	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_80bw1s_160bw1s_b,	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_80bw2s_160bw2s_b, MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_80bw3s_160bw3s_b,	MAX_5G_DIFF_NUM * sizeof(unsigned char))
	CHECK_AND_COPY_FIELD(tx_power_diff_5g_80bw4s_160bw4s_b,	MAX_5G_DIFF_NUM * sizeof(unsigned char))


	return error_or_parameter;
}


int main ( int argc, char *argv[] ) {

	// Must have the parameter name
	if (argc < 2 || (argc - 1) % 2 != 0) {
		print_usage(argv[0]);

		return OK;
	}


	// Compare strings and parameters
	// Help
	if (argc == 2 && !strncmp(argv[1], "--help", 6)) {
		print_usage(argv[0]);
	}

	else if ( (argc - 1) % 2 == 0){

		// Read the MTD
		result_mib mib = read_mtd();

		// An error occurred?
		if (mib.error) {

			if (mib.error_string != NULL)
				printf ("[ ERROR ] %s (code: %d)", mib.error_string, mib.error);

			return mib.error;

		}


		// Get every parameter from argv
		unsigned int num_parameter = 1;

		while((num_parameter + 1) < argc) {

			// Get the interface number
			char* last_char;
			long interface = strtol(argv[num_parameter], &last_char, 10);

			// Check for error finding interface number
			if (errno != 0 || *last_char != '\0' || interface > NUM_WLAN_INTERFACE || interface <= 0) {

				printf("[ ERROR ] Invalid interface.\n");
				print_usage(argv[0]);

				return INVALID_INTERFACE;
			}


			// Get the parameter
			// Subtract one from interface to access the array
			result_mib_value parameter = get_mib_parameter(&mib.mib, argv[num_parameter + 1], (unsigned short) interface - 1);

			// An error occurred?
			if (parameter.error) {

				if (parameter.error_string != NULL)
					printf ("[ ERROR ] %s (code: %d)", parameter.error_string, parameter.error);

				return parameter.error;

			}


			// Print the result
			// Entrys with tx_power_diff_5g and size MAX_5G_DIFF_NUM, have a different
			// print method
			if (!strncmp(argv[num_parameter + 1], "tx_power_diff_5g", strlen("tx_power_diff_5g")) &&
				parameter.size == MAX_5G_DIFF_NUM)

				// Make sure the parameter does not haver more than MAX_5G_DIFF_NUM
				// chars
				print_power_diff(parameter.value);


			// Transform single char into int
			else if (parameter.size == sizeof(unsigned char))
				printf("%d ", (unsigned int) parameter.value[0]);


			// If it is a mac address, print with :
			else if (!strncmp(argv[num_parameter + 1], "mac_address", strlen("mac_address")) &&
				parameter.size == MAC_ADDRESS_SIZE)

				printf("%02X:%02X:%02X:%02X:%02X:%02X ", PRINT_MAC(parameter.value));


			// Array of hex numbers
			else {

				unsigned int count;

				for (count = 0; count < parameter.size; count++)
					printf("%02X", parameter.value[count]);

				printf(" ");

			}

			num_parameter += 2;

		}

	}

	else
		print_usage(argv[0]);


	return OK;
}