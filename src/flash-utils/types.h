#ifndef TYPES_H
#define TYPES_H

#include "constants.h"


typedef enum {
	
	OK,

	// Files
	FILE_NOT_OPENED,
	FILE_NOT_CLOSED,
	FILE_NOT_READ,

	// MIB
	INVALID_PARTITION,
	ENTRY_NOT_FOUND,
	INVALID_INTERFACE,
	
	NULL_POINTER,

} error_code;


typedef struct {	

	unsigned char	mac_address1						[MAC_ADDRESS_SIZE];
	unsigned char	mac_address2						[MAC_ADDRESS_SIZE];
	unsigned char	mac_address3						[MAC_ADDRESS_SIZE];
	unsigned char	mac_address4						[MAC_ADDRESS_SIZE];
	unsigned char	mac_address5						[MAC_ADDRESS_SIZE];
	unsigned char	mac_address6						[MAC_ADDRESS_SIZE];
	unsigned char	mac_address7						[MAC_ADDRESS_SIZE];
	unsigned char	mac_address8						[MAC_ADDRESS_SIZE];

	unsigned char	power_level_cck_a					[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	power_level_cck_b					[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	power_level_ht40_1s_a				[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	power_level_ht40_1s_b				[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	power_diff_ht40_2s					[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	power_diff_ht20						[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	power_diff_ofdm						[MAX_2G_CHANNEL_NUM_MIB];
	
	unsigned char	reg_domain;
	unsigned char	rf_type;
	unsigned char	led_type;
	unsigned char	x_cap;
	unsigned char	tssi1;
	unsigned char	tssi2;
	unsigned char	thermal;
	unsigned char	tr_switch;
	unsigned char	tr_swpape_c9;
	unsigned char	tr_swpape_cc;
	unsigned char	target_power;
	unsigned char	pa_type;
	unsigned char	thermal2;
	unsigned char	thermal3;
	unsigned char	thermal4;
	unsigned char	x_cap2;
	unsigned char	kfree_enable;
	unsigned char	reserved9;
	unsigned char	reserved10;

	unsigned char	tx_power_5g_ht40_1s_a				[MAX_5G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_5g_ht40_1s_b				[MAX_5G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_5g_ht40_2s			[MAX_5G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_5g_ht20				[MAX_5G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_5g_ofdm				[MAX_5G_CHANNEL_NUM_MIB];

	unsigned char	tx_power_tssi_cck_a					[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_cck_b					[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_cck_c					[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_cck_d					[MAX_2G_CHANNEL_NUM_MIB];

	unsigned char	tx_power_tssi_ht40_1s_a				[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_ht40_1s_b				[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_ht40_1s_c				[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_ht40_1s_d				[MAX_2G_CHANNEL_NUM_MIB];

	unsigned char	tx_power_tssi_5g_ht40_1s_a			[MAX_5G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_5g_ht40_1s_b			[MAX_5G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_5g_ht40_1s_c			[MAX_5G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_tssi_5g_ht40_1s_d			[MAX_5G_CHANNEL_NUM_MIB];

	unsigned char	tssi_enable;
	unsigned char	wsc_pin								[9];

	unsigned char	tx_power_diff_20bw1s_ofdm1t_a		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_40bw2s_20bw2s_a		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_ofdm2t_cck2t_a		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_40bw3s_20bw3s_a		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_ofdm3t_cck3t_a		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_40bw4s_20bw4s_a		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_ofdm4t_cck4t_a		[MAX_2G_CHANNEL_NUM_MIB];

	unsigned char	tx_power_diff_5g_20bw1s_ofdm1t_a	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_40bw2s_20bw2s_a	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_40bw3s_20bw3s_a	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_40bw4s_20bw4s_a	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_rsvd_ofdm4t_a		[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_80bw1s_160bw1s_a	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_80bw2s_160bw2s_a	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_80bw3s_160bw3s_a	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_80bw4s_160bw4s_a	[MAX_5G_DIFF_NUM];

	unsigned char	tx_power_diff_20bw1s_ofdm1t_b		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_40bw2s_20bw2s_b		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_ofdm2t_cck2t_b		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_40bw3s_20bw3s_b		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_ofdm3t_cck3t_b		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_40bw4s_20bw4s_b		[MAX_2G_CHANNEL_NUM_MIB];
	unsigned char	tx_power_diff_ofdm4t_cck4t_b		[MAX_2G_CHANNEL_NUM_MIB];

	unsigned char	tx_power_diff_5g_20bw1s_ofdm1t_b	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_40bw2s_20bw2s_b	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_40bw3s_20bw3s_b	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_40bw4s_20bw4s_b	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_rsvd_ofdm4t_b		[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_80bw1s_160bw1s_b	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_80bw2s_160bw2s_b	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_80bw3s_160bw3s_b	[MAX_5G_DIFF_NUM];
	unsigned char	tx_power_diff_5g_80bw4s_160bw4s_b	[MAX_5G_DIFF_NUM];

} realtek_wlan_mib;


typedef struct {

	unsigned char		signature						[4];
	unsigned char		board_version					[3];
	unsigned char		nic0_address					[MAC_ADDRESS_SIZE];
	unsigned char		nic1_address					[MAC_ADDRESS_SIZE];

#ifdef CONFIG_DEVICE_W5_1200F
	char				hw_date							[127];
#endif

	realtek_wlan_mib	wlan_mib						[NUM_WLAN_INTERFACE];

} realtek_mib;


// Result: OK + mib or Error + String
typedef struct {

	error_code 		error;

	// The ideia is to have a union, but it would be more dangerous
	char *			error_string;
	realtek_mib 	mib;

} result_mib;

typedef struct {
	
	error_code		error;

	union {
		char *			error_string;

		struct {
			// Pointer and size to the real value in mib
			unsigned char			value	[MAX_VALUE_SIZE];
			size_t 					size;
		};
	};			

} result_mib_value;

#endif // TYPES_H