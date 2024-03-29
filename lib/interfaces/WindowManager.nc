#include "../../includes/socket.h"
#include "../../includes/TCP_packet.h"

interface WindowManager {
   command uint8_t receiveACK(socket_t fd, TCP_packet_t* payload);
   command error_t receiveData(socket_t fd, TCP_packet_t* payload);
   command error_t initData(socket_t fd, uint8_t* data, uint16_t* sequenceNum);
   command void readData(socket_t fd);
   command void setWindowInfo(socket_t fd, uint16_t size);
   command void init(socket_t fd);
}
