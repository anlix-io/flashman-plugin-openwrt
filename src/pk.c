/*
 *  Public key-based signature verification program
 *
 *  Copyright (C) 2006-2015, ARM Limited, All Rights Reserved
 *  SPDX-License-Identifier: GPL-2.0
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 *
 * echo 'teste' | openssl base64 | openssl dgst -sha256 -sign provedor.key | openssl base64 
 */

#if !defined(MBEDTLS_CONFIG_FILE)
#include "mbedtls/config.h"
#else
#include MBEDTLS_CONFIG_FILE
#endif

#if defined(MBEDTLS_PLATFORM_C)
#include "mbedtls/platform.h"
#else
#include <stdio.h>
#include <stdlib.h>
#define mbedtls_snprintf        snprintf
#define mbedtls_printf          printf
#define mbedtls_exit            exit
#define MBEDTLS_EXIT_SUCCESS    EXIT_SUCCESS
#define MBEDTLS_EXIT_FAILURE    EXIT_FAILURE
#endif /* MBEDTLS_PLATFORM_C */

#if !defined(MBEDTLS_BIGNUM_C) || !defined(MBEDTLS_MD_C) || \
    !defined(MBEDTLS_SHA256_C) || !defined(MBEDTLS_PK_PARSE_C) ||   \
    !defined(MBEDTLS_FS_IO)
int main( void )
{
    mbedtls_printf("MBEDTLS_BIGNUM_C and/or MBEDTLS_MD_C and/or "
           "MBEDTLS_SHA256_C and/or MBEDTLS_PK_PARSE_C and/or "
           "MBEDTLS_FS_IO not defined.\n");
    return( 0 );
}
#else

#include "mbedtls/error.h"
#include "mbedtls/md.h"
#include "mbedtls/pk.h"
#include "mbedtls/base64.h"

#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"

#include <stdio.h>
#include <string.h>

int readfile(char *filename, unsigned char *buffer, int sizebuf)
{
    FILE *f;
    int i;
    if( ( f = fopen( filename, "rb" ) ) == NULL )
        return 0;

    i = fread( buffer, 1, sizebuf, f );
    fclose( f );

    return i;
}

#define MAX_BUF_SIZE 512

int main( int argc, char *argv[] )
{
    int ret = 1;
    int exit_code = MBEDTLS_EXIT_FAILURE;
    mbedtls_pk_context pk;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context ctr_drbg;
    unsigned char hash[32];
    unsigned char bufin[MAX_BUF_SIZE];
    unsigned char bufout[MAX_BUF_SIZE];
    const char *pers = "mbedtls_pk_sign";
    char filename[64];
    size_t ilen, olen;

    mbedtls_pk_init( &pk );
    mbedtls_entropy_init( &entropy );
    mbedtls_ctr_drbg_init( &ctr_drbg );

    if( argc < 3 )
        goto exit;

    if ((strncmp(argv[1], "b64enc", 6) == 0) ||  (strncmp(argv[1], "b64dec", 6) == 0)) {
        ilen = readfile(argv[2], bufin, sizeof( bufin ));
        if(ilen < 0)
            goto exit;
        // convert to base64
        if (strncmp(argv[1], "b64enc", 6) == 0) {
            if( mbedtls_base64_encode( bufout, sizeof( bufout ), &olen, bufin, ilen ) != 0 )
                goto exit;
        }
        else {
            if( mbedtls_base64_decode( bufout, sizeof( bufout ), &olen, bufin, ilen ) != 0 )
                goto exit;       
        }

        if(olen>=sizeof( bufout )-1) 
            bufout[sizeof( bufout )-1] = 0;
        else
            bufout[olen]=0;
        printf("%s", bufout);

        exit_code = MBEDTLS_EXIT_SUCCESS;
        goto exit;
    }

    if( argc < 4 )
        goto exit;

    /*
     * Compute the SHA-256 hash of the input file
     */
    if( ( ret = mbedtls_md_file(
                    mbedtls_md_info_from_type( MBEDTLS_MD_SHA256 ),
                    argv[3], hash ) ) != 0 )
        goto exit;

    if (strncmp(argv[1], "sign", 4) == 0) {
        if( ( ret = mbedtls_ctr_drbg_seed( &ctr_drbg, mbedtls_entropy_func, &entropy,
               (const unsigned char *) pers, strlen( pers ) ) ) != 0 )
            goto exit;

        if( ( ret = mbedtls_pk_parse_keyfile( &pk, argv[2], "" ) ) != 0 )
            goto exit;

        if( ( ret = mbedtls_pk_sign( &pk, MBEDTLS_MD_SHA256, hash, 0, bufin, &ilen,
                         mbedtls_ctr_drbg_random, &ctr_drbg ) ) != 0 )
            goto exit;

        if( mbedtls_base64_encode( bufout, sizeof( bufout ), &olen, bufin, ilen ) != 0 )
            goto exit; 

        if(olen>=sizeof( bufout )-1) 
            bufout[sizeof( bufout )-1] = 0;
        else
            bufout[olen]=0;
        printf("%s\n", bufout);
    }

    if (strncmp(argv[1], "verify", 6) == 0) {
        if( ( ret = mbedtls_pk_parse_public_keyfile( &pk, argv[2] ) ) != 0 )
            goto exit;

        snprintf( filename, sizeof(filename), "%s.sig", argv[3] );

        ilen = readfile(filename, bufin, sizeof( bufin ));
        if( mbedtls_base64_decode( bufout, sizeof( bufout ), &olen, bufin, ilen ) != 0 )
            goto exit; 

        if( ( ret = mbedtls_pk_verify( &pk, MBEDTLS_MD_SHA256, hash, 0,
                           bufout, olen ) ) != 0 )
            goto exit;

        printf("OK\n");
    }

    exit_code = MBEDTLS_EXIT_SUCCESS;

exit:
    mbedtls_pk_free( &pk );
    mbedtls_ctr_drbg_free( &ctr_drbg );
    mbedtls_entropy_free( &entropy );

    if( exit_code != MBEDTLS_EXIT_SUCCESS )
        mbedtls_printf("FAIL\n");

    return( exit_code );
}
#endif /* MBEDTLS_BIGNUM_C && MBEDTLS_SHA256_C &&
          MBEDTLS_PK_PARSE_C && MBEDTLS_FS_IO */
