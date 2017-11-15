#ifndef __WINDOW_INFO_H__
#define __WINDOW_INFO_H__

enum {
   WINDOW_DEFAULT_STATUS               = FALSE,
   WINDOW_DEFAULT_DATA_IN_TRANSFER     = 0,
   WINDOW_DEFAULT_MAX_DATA_IN_TRANSFER = 5,
   WINDOW_DEFAULT_TIMEOUT              = 5,
   WINDOW_DEFAULT_VALUE                = 24,
   WINDOW_DEFAULT_BYTE_STREAM          = 0
};

typedef struct{
    bool completed; // endOfDataReached
    uint16_t size; // transferSize
    uint16_t prev; // lastValue
    uint8_t dataTransfer; // inFlight
    uint8_t maxDataTransfer; // maxInFlight
    uint8_t timeout; // closeTime
    uint8_t synTimeout; // timeWithoutAck
    uint8_t window; // advertisedWindow
    uint8_t bytesInStream;
} window_info_t;

#endif
