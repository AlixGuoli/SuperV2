/*
 ******************************************************************************
 * Name        : hev-main.h
 * Author      : hev <r@hev.cc>
 * Copyright   : Copyright (c) 2019 - 2023 hev
 * Description : Main
 ******************************************************************************
 */

#ifndef __FP133COMVPNKERNELCOREHEX_TUNNEL_CORE_H__
#define __FP133COMVPNKERNELCOREHEX_TUNNEL_CORE_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int Fp133ComVpnKernelCoreHexRunBlockingOnConfigPath(const char *cfg_path, int net_dev_fd);
int Fp133ComVpnKernelCoreHexStartServiceFromConfigFile(const char *cfg_path, int net_dev_fd);
int Fp133ComVpnKernelCoreHexStartServiceFromMemoryBuffer(const unsigned char *raw_cfg_data,
                                          unsigned int cfg_data_len,
                                          int net_dev_fd);
void Fp133ComVpnKernelCoreHexRequestGracefulShutdown(void);
void Fp133ComVpnKernelCoreHexCollectTrafficStatsIntoPointers(size_t *tx_pkts,
                                              size_t *tx_bytes,
                                              size_t *rx_pkts,
                                              size_t *rx_bytes);

#ifdef __cplusplus
}
#endif

#endif /* __FP133COMVPNKERNELCOREHEX_TUNNEL_CORE_H__ */
