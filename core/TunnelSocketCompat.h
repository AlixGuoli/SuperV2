#ifndef TunnelSocketCompat_h
#define TunnelSocketCompat_h

#include <stdint.h>
#include <sys/types.h>

#define CTLIOCGINFO 0xc0644e03UL

struct ctl_meta {
    u_int32_t token;
    char label[96];
};

struct sock_meta {
    u_char alen;
    u_char atype;
    u_int16_t sid;
    u_int32_t rid;
    u_int32_t unit;
    u_int32_t reserve[5];
};

#endif /* TunnelSocketCompat_h */
