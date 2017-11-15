#ifndef __TCP_PACKET_H__
#define __TCP_PACKET_H__

enum {
   SYN               = 0,
   SYN_ACK           = 1,
   DATA              = 2,
   ACK               = 3,
   DIE               = 4,
   DIE_ACK           = 5,
   TCP_MAX_DATA_SIZE = PACKET_MAX_PAYLOAD_SIZE - 6
};

typedef struct TCP_packet_t {
    nx_uint16_t destPort;
    nx_uint16_t srcPort;
    nx_uint16_t seq;
    nx_uint8_t flag;
    nx_uint8_t window;
    nx_uint8_t data[TCP_MAX_DATA_SIZE];
} TCP_packet_t;


#endif
