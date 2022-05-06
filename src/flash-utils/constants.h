#ifndef CONSTANTS_H
#define CONSTANTS_H

#define MTD_CONFIGURATION_LOCATION			"/dev/mtd1"
#define MTD_PARTITION_SIGNATURE				"H601"
#define MAX_CCK_CHAN_NUM					14
#define MAX_OFDM_CHAN_NUM					162
#define MAX_2G_CHANNEL_NUM_MIB				14
#define MAX_5G_CHANNEL_NUM_MIB				196
#define MAX_5G_DIFF_NUM						14
#define BYTES_TO_READ						10
#define MAC_ADDRESS_SIZE					6
#define MAX_VALUE_SIZE						255
#define NUM_WLAN_INTERFACE					2 		// 2 interfaces (2.4G and 5G)

#define PRINT_MAC(addr)						addr[0], addr[1], addr[2], addr[3], addr[4], addr[5]

char FILE_NOT_CLOSED_STRING[]				= "File not closed.\n";
char INVALID_PARTITION_STRING[]				= "Invalid partition signature.\n";
char ENTRY_NOT_FOUND_STRING[]				= "MIB entry not found.\n";
char INVALID_INTERFACE_STRING[]				= "Invalid interface number.\n";
char NULL_POINTER_STRING[]					= "NULL pointer.\n";

const unsigned int CHANNEL_SIZES[]			= {5, 8, 8, 8, 5, 8, 8, 8, 8, 8, 9, 8, 8, 8};

#endif // CONSTANTS_H