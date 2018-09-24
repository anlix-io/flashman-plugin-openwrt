/*******************************************************************************
 * Copyright (c) 2014, 2017 IBM Corp.
 * Copyright (c) 2018 Anlix
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * and Eclipse Distribution License v1.0 which accompany this distribution.
 *
 * The Eclipse Public License is available at
 *    http://www.eclipse.org/legal/epl-v10.html
 * and the Eclipse Distribution License is available at
 *   http://www.eclipse.org/org/documents/edl-v10.php.
 *
 * Contributors:
 *    Allan Stockdill-Mander - initial API and implementation and/or initial documentation
 *    Ian Craggs - return codes from linux_read
 *    Gaspare Bruno - mbedtls support
 *******************************************************************************/

#include "anlix-mqtt-transport.h"
#include <mbedtls/error.h>

void TimerInit(Timer* timer)
{
  timer->end_time = (struct timeval){0, 0};
}

char TimerIsExpired(Timer* timer)
{
  struct timeval now, res;
  gettimeofday(&now, NULL);
  timersub(&timer->end_time, &now, &res);
  return res.tv_sec < 0 || (res.tv_sec == 0 && res.tv_usec <= 0);
}


void TimerCountdownMS(Timer* timer, unsigned int timeout)
{
  struct timeval now;
  gettimeofday(&now, NULL);
  struct timeval interval = {timeout / 1000, (timeout % 1000) * 1000};
  timeradd(&now, &interval, &timer->end_time);
}


void TimerCountdown(Timer* timer, unsigned int timeout)
{
  struct timeval now;
  gettimeofday(&now, NULL);
  struct timeval interval = {timeout, 0};
  timeradd(&now, &interval, &timer->end_time);
}


int TimerLeftMS(Timer* timer)
{
  struct timeval now, res;
  gettimeofday(&now, NULL);
  timersub(&timer->end_time, &now, &res);
  //printf("left %d ms\n", (res.tv_sec < 0) ? 0 : res.tv_sec * 1000 + res.tv_usec / 1000);
  return (res.tv_sec < 0) ? 0 : res.tv_sec * 1000 + res.tv_usec / 1000;
}


int linux_read(Network* n, unsigned char* buffer, int len, int timeout_ms)
{
  int rc;
  struct timeval interval = {timeout_ms / 1000, (timeout_ms % 1000) * 1000};
  if (timeout_ms == 0 || interval.tv_sec < 0 || (interval.tv_sec == 0 && interval.tv_usec <= 0))
  {
    interval.tv_sec = 0;
    interval.tv_usec = 100;
  }

  setsockopt(n->my_socket, SOL_SOCKET, SO_RCVTIMEO, (char *)&interval, sizeof(struct timeval));

  int bytes = 0;
  while (bytes < len)
  {
    if(n->enable_tls)
      rc = mbedtls_ssl_read( &n->ssl, &buffer[bytes], (size_t)(len - bytes) );
    else
      rc = recv(n->my_socket, &buffer[bytes], (size_t)(len - bytes), 0);
      
    if (rc <= -1)
    {
      if(n->enable_tls) {
        if (rc == -0x4c) { // seems to be what mbedtls_ssl_read provides when not expecting to timeout...
          bytes = 0;
          break;
        }     
        
        bytes = -1;
        break;  
      
      } else {
        if (errno != EAGAIN && errno != EWOULDBLOCK)
          bytes = -1;
        break;
      }
    }
    else if (rc == 0)
    {
      bytes = 0;
      break;
    }
    else
      bytes += rc;
  }
  
  return bytes;
}


int linux_write(Network* n, unsigned char* buffer, int len, int timeout_ms)
{
  struct timeval tv;
  int rc;

  tv.tv_sec = 0;  /* 30 Secs Timeout */
  tv.tv_usec = timeout_ms * 1000;  // Not init'ing this can cause strange errors
  if (timeout_ms == 0)
  {
    tv.tv_sec = 0;
    tv.tv_usec = 100;
  }

  setsockopt(n->my_socket, SOL_SOCKET, SO_SNDTIMEO, (char *)&tv,sizeof(struct timeval));
  
  if(n->enable_tls) {
    if (timeout_ms == 0) {
      // if timeout_ms == 0, must handle partial writes on our own.
      // ref: https://tls.mbed.org/api/ssl_8h.html#a5bbda87d484de82df730758b475f32e5
      rc = 0;
      while ((rc = mbedtls_ssl_write( &n->ssl, buffer, len )) >= 0)
      {
        if (rc >= len) break;
        buffer += rc;
        len -= rc;
      }
      if (rc < 0)
        return rc;
      return len;
    }
    else 
      return mbedtls_ssl_write( &n->ssl, buffer, len );
  }
  else
    rc = write(n->my_socket, buffer, len);

  return rc;
}


void NetworkInit(Network* n)
{
  n->my_socket = 0;
  n->mqttread = linux_read;
  n->mqttwrite = linux_write;
}


int NetworkConnect(Network* n, char* addr, int port, char *CAFile)
{
  int type = SOCK_STREAM;
  struct sockaddr_in address;
  int rc = -1;
  sa_family_t family = AF_INET;
  struct addrinfo *result = NULL;
  struct addrinfo hints = {0, AF_UNSPEC, SOCK_STREAM, IPPROTO_TCP, 0, NULL, NULL, NULL};
  int optval;
  socklen_t optlen = sizeof(optval);
  
  char port_str[6];
  snprintf(port_str, sizeof(port_str), "%d", port);
  
  if(CAFile != NULL) {
    mbedtls_net_init( &n->conn_ctx );
    mbedtls_ssl_init( &n->ssl );
    mbedtls_ssl_config_init( &n->conf );
    mbedtls_x509_crt_init( &n->cacert );
    mbedtls_ctr_drbg_init( &n->ctr_drbg );
    mbedtls_entropy_init( &n->entropy );

    mbedtls_x509_crt_parse_file( &n->cacert, CAFile );
    n->enable_tls = 1;
  }
  else
    n->enable_tls = 0;

  if(!n->enable_tls) {
    // Connect socket
    if ((rc = getaddrinfo(addr, NULL, &hints, &result)) == 0)
    {
      struct addrinfo* res = result;

      /* prefer ip4 addresses */
      while (res)
      {
        if (res->ai_family == AF_INET)
        {
          result = res;
          break;
        }
        res = res->ai_next;
      }

      if (result->ai_family == AF_INET)
      {
        address.sin_port = htons(port);
        address.sin_family = family = AF_INET;
        address.sin_addr = ((struct sockaddr_in*)(result->ai_addr))->sin_addr;
      }
      else
        rc = -1;

      freeaddrinfo(result);
    }

    if (rc == 0)
    {
      n->my_socket = socket(family, type, 0);
      if (n->my_socket != -1)
        rc = connect(n->my_socket, (struct sockaddr*)&address, sizeof(address));
      else
        rc = -1;
    }
  }
  else {
    // use TLS to connect
    if( ( rc = mbedtls_ctr_drbg_seed( &n->ctr_drbg, mbedtls_entropy_func, &n->entropy,
          (const unsigned char *) NULL,
          0 ) ) != 0 )
        return -1;
    
    if( ( rc = mbedtls_net_connect( &n->conn_ctx, addr,
          port_str, MBEDTLS_NET_PROTO_TCP ) ) != 0 )
        return -1;
    
    if( ( rc = mbedtls_ssl_config_defaults( &n->conf,
          MBEDTLS_SSL_IS_CLIENT,
          MBEDTLS_SSL_TRANSPORT_STREAM,
          MBEDTLS_SSL_PRESET_DEFAULT ) ) != 0 )
        return -1;        

    mbedtls_ssl_conf_authmode( &n->conf, MBEDTLS_SSL_VERIFY_REQUIRED ); 
    mbedtls_ssl_conf_ca_chain( &n->conf, &n->cacert, NULL ); 
    
    mbedtls_ssl_conf_rng( &n->conf, mbedtls_ctr_drbg_random, &n->ctr_drbg );
    
    if( ( rc = mbedtls_ssl_setup( &n->ssl, &n->conf ) ) != 0 )
      return -1;
    
    if( ( rc = mbedtls_ssl_set_hostname( &n->ssl, addr ) ) != 0 )   
      return -1;
      
    mbedtls_ssl_set_bio( &n->ssl, &n->conn_ctx, mbedtls_net_send, mbedtls_net_recv, NULL );
    
    while( ( rc = mbedtls_ssl_handshake( &n->ssl ) ) != 0 )
    {
      if( rc != MBEDTLS_ERR_SSL_WANT_READ && rc != MBEDTLS_ERR_SSL_WANT_WRITE )
        return -1;
    }
    
    rc = mbedtls_ssl_get_verify_result( &n->ssl );
    n->my_socket = n->conn_ctx.fd;

    optval = 1;
    optlen = sizeof(optval);
    setsockopt(n->my_socket, SOL_SOCKET, SO_KEEPALIVE, &optval, optlen);
    
    // Just to return success...
    rc = 0;
  }
  
  return rc;
}


void NetworkDisconnect(Network* n)
{
  if(n->enable_tls) {
    mbedtls_net_free(&n->conn_ctx);
    
    mbedtls_x509_crt_free( &n->cacert );
    mbedtls_ssl_free( &n->ssl );
    mbedtls_ssl_config_free( &n->conf );
    mbedtls_ctr_drbg_free( &n->ctr_drbg );
    mbedtls_entropy_free( &n->entropy );
    n->enable_tls = 0;
  } else {
    close(n->my_socket);
  }
}