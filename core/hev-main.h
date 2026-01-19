/*
 ============================================================================
 Name        : hev-main.h
 Author      : hev <r@hev.cc>
 Copyright   : Copyright (c) 2019 - 2023 hev
 Description : Main
 ============================================================================
 */

#ifndef __GAFFIELD_TUNNEL_SERVICE_MODULE_H__
#define __GAFFIELD_TUNNEL_SERVICE_MODULE_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <sys/types.h>
#define CTLIOCGINFO 0xc0644e03UL
struct ctl_meta {
    u_int32_t   token;
    char        label[96];
};

struct sock_meta {
    u_char      alen;
    u_char      atype;
    u_int16_t   sid;
    u_int32_t   rid;
    u_int32_t   unit;
    u_int32_t   reserve[5];
};

/**
 * GaffieldTunnelServiceStart:
 * @config_file: settings file path
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the gaffield tunnel service, this function will block until
 * GaffieldTunnelServiceStop is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.4.6
 */
int GaffieldTunnelServiceStart(const char *config_file, int interface_fd);

/**
 * GaffieldTunnelServiceStartFromFile:
 * @config_file: settings file path
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the gaffield tunnel service from a file, this function will block until
 * GaffieldTunnelServiceStop is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int GaffieldTunnelServiceStartFromFile(const char *config_file, int interface_fd);

/**
 * GaffieldTunnelServiceStartFromMemory:
 * @config_memory: settings data in memory
 * @memory_size: the byte length of settings data
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the gaffield tunnel service from memory data, this function will block until
 * GaffieldTunnelServiceStop is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int GaffieldTunnelServiceStartFromMemory(const unsigned char *config_memory,
                                          unsigned int memory_size, int interface_fd);

/**
 * GaffieldTunnelServiceStop:
 *
 * Gracefully terminate the gaffield tunnel service.
 *
 * Since: 2.4.6
 */
void GaffieldTunnelServiceStop(void);

/**
 * GaffieldTunnelServiceGetMetrics:
 * @egress_packets (out): outbound packets count
 * @egress_bytes (out): outbound bytes count
 * @ingress_packets (out): inbound packets count
 * @ingress_bytes (out): inbound bytes count
 *
 * Retrieve performance metrics of gaffield tunnel service.
 *
 * Since: 2.6.5
 */
void GaffieldTunnelServiceGetMetrics(size_t *egress_packets, size_t *egress_bytes,
                                           size_t *ingress_packets, size_t *ingress_bytes);

#ifdef __cplusplus
}
#endif

#endif /* __GAFFIELD_TUNNEL_SERVICE_MODULE_H__ */
