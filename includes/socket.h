#ifndef __STRUCT_H__
#define __STRUCT_H__

typedef enum socketState{
   SOCK_ESTABLISHED  = 0,
   SOCK_LISTEN       = 1,
   SOCK_CLOSED       = 2,
   SOCK_SYN_SENT     = 3,
   SOCK_CLOSE_WAIT   = 4,
   SOCK_FIN_WAIT     = 5
}socketState;

enum{
    MAX_SOCKET_COUNT = 99,
    SOCKET_SEND_BUFFER_SIZE = 128,
    SOCKET_RECEIVE_BUFFER_SIZE = 128,
    NULL_SOCKET = 0
};

typedef nx_struct socket_addr_t {
   nx_uint8_t srcPort;
   nx_uint8_t destPort;
   nx_uint16_t srcAddr;
   nx_uint16_t destAddr;
} socket_addr_t;

typedef struct socket_storage_t{
    socketState state;
    socket_addr_t sockAddr;
    uint8_t sendBuff[SOCKET_SEND_BUFFER_SIZE];
    uint8_t recBuff[SOCKET_RECEIVE_BUFFER_SIZE];
    uint8_t timeout;
    uint16_t seqNum;
    uint16_t lastByteSent;
    uint16_t lastByteWritten;
    uint16_t lastByteAck;
    uint16_t lastByteRec;
    uint16_t lastByteRead;
    uint16_t lastByteExpected;
}socket_storage_t;

typedef uint16_t socket_t;

#endif
