#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCP_packet.h"

module TransportP{
    provides interface Transport;

    uses interface SocketPointerMap;

    uses interface RouterTable;

    uses interface Connections;

    uses interface SimpleSend as Sender;

    uses interface LiveSocketList;

    uses interface WindowManager;
}

implementation{
   pack sendPackage;
   uint16_t seqNum = 0;
   uint8_t data[TCP_MAX_DATA_SIZE];

   uint16_t assignSocketID();

   socket_addr_t assignTempAddress(nx_uint8_t srcPort, nx_uint8_t destPort, nx_uint16_t srcAddr, nx_uint16_t destAddr);

   socket_addr_t assignTempAddress(nx_uint8_t srcPort, nx_uint8_t destPort, nx_uint16_t srcAddr, nx_uint16_t destAddr) {
       socket_addr_t socketAddress;
                     socketAddress.srcPort = srcPort;
                     socketAddress.destPort = destPort;
                     socketAddress.srcAddr = srcAddr;
                     socketAddress.destAddr = destAddr;

          return socketAddress;
   }

   void sendWithTimerPing(pack *Package)

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, TCPpacket_t *payload, uint8_t length);

   void makeTCPPack(TCPpacket_t *Package, uint8_t srcPort, uint8_t destPort, uint16_t seq, uint8_t flag, uint8_t window, uint8_t *data, uint8_t length);

   void sendWithTimerPing(pack *Package) {
       uint8_t finalDestination = Package -> dest;
       uint8_t nextDestination = finalDestination;
       uint8_t preventRun = 0;
       RouterTableRow row;

       while((!call RouterTable.contains(nextDestination)) && preventRun < 999) {
           nextDestination++;

           if(nextDestination >= MAX_NODE_COUNT) {
               nextDestination = 1;
           }

           preventRun++;
       }

       row = call RouterTable.get(nextDestination);

       if(row.distance == 1) {
           call Sender.send(sendPackage, finalDestination);
       } else {
           call Sender.send(sendPackage, row.nextNode);
       }

   }

   uint16_t assignSocketID() {
       uint16_t socketID = 1;

       while (call SocketPointerMap.contains(socketID)) {
           socketID++;
       }

       return socketID;
   }

   command socket_t Transport.socket() {
        int pointerLocation = -1;
        socket_t fd;
        socket_storage_t tempSocket;
                         tempSocket.state = SOCK_CLOSED;
                         tempSocket.startup_closeTimer = 6;
                         tempSocket.lastByteAck = 1;
                         tempSocket.lastByteSent = 0;
                         tempSocket.initialSequenceNum = 0;
                         tempSocket.lastByteRec = 0;
                         tempSocket.lastByteWritten = 0;
                         tempSocket.lastByteRead = 0;
                         tempSocket.lastByteExpected = 0;

        if (call SocketPointerMap.isFull()) {
            return NULL_SOCKET;
        }

        fd = assignSocketID();
        pointerLocation = call LiveSocketList.insert(fd, tempSocket);

        if (pointerLocation != -1) {
            call SocketPointerMap.insert(fd, call LiveSocketList.getStore(pointerLocation));

            return fd;
        }

        return NULL_SOCKET;
   }

   command error_t Transport.bind(socket_t fd, socket_addr_t *socketAddress) {
      socket_storage_t* tempSocketAddress;

      if (call LiveSocketList.contains(fd)) {
         tempSocketAddress = call LiveSocketList.get(fd);
         tempSocketAddress -> sockAddr.srcPort  = socketAddress -> srcPort;
         tempSocketAddress -> sockAddr.destPort = socketAddress -> destPort;
         tempSocketAddress -> sockAddr.srcAddr  = socketAddress -> srcAddr;
         tempSocketAddress -> sockAddr.destAddr = socketAddress -> destAddr;

         return SUCCESS;
      }

      dbg("Project3TGen", "Error: can't bind!\n");
      return FAIL;
   }

   command void Transport.accept() {
        socket_t fd = call Transport.socket();
        socket_storage_t* tempSocket;

        socket_addr_t newConnection = call Connections.popfront();
        socket_addr_t socketAddress;

        if (fd != NULL_SOCKET) {
            // reverse the address
            socketAddress = assignTempAddress(newConnection.destPort,
                                              newConnection.srcPort,
                                              newConnection.destAddr,
                                              newConnection.srcAddr);

           if (call Transport.bind(fd, &socketAddress) == SUCCESS) {
              tempSocket = call LiveSocketList.get(fd);

               // SYN_ACK
               makeTCPPack(&sendPayload, tempSocketAddr.srcPort, tempSocketAddr.destPort, 0, SYN_ACK, 0, sendPayload.data, TCP_MAX_DATA_SIZE);

               makePack(&sendPackage, tempSocketAddr.srcAddr, tempSocketAddr.destAddr, MAX_TTL, PROTOCOL_TCP, seqNum, &sendPayload, PACKET_MAX_PAYLOAD_SIZE);

               seqNum++;

               sendWithTimerPing(&sendPackage);

               tempSocket -> state = SOCK_SYN_SENT;
               return;
           }
        }
   }

   command void Transport.write(socket_t fd, uint8_t flag) {
        socket_storage_t* tempSocket;
        uint16_t sequenceNum;
        uint8_t advertisedWindow;

        if (call LiveSocketList.contains(fd)) {
            tempSocket = call LiveSocketList.get(fd);

            switch (flag) {
                case DATA :
                    if (call WindowManager.init(fd, &data,  &sequenceNum) == FAIL) {
                        return;
                    }

                    advertisedWindow = 0;
                    break;
                case ACK :
                    sequenceNum = tempSocket->lastByteExpected;
                    advertisedWindow = 70 - (tempSocket -> lastByteExpected - tempSocket -> lastByteRead);
                    break;
                case FIN :
                    sequenceNum = tempSocket -> lastByteSent;
                    advertisedWindow = 0;
                    break;
                case FIN_ACK :
                    sequenceNum = tempSocket -> lastByteExpected;
                    advertisedWindow = 0;
                    break;
                default :
                    return;
            }



            makeTCPPack(&sendPayload, tempSocket->sockAddr.srcPort, tempSocket->sockAddr.destPort, sequenceNum, flag, advertisedWindow, &data, TCP_MAX_DATA_SIZE);

            makePack(&sendPackage, tempSocket->sockAddr.srcAddr, tempSocket->sockAddr.destAddr, MAX_TTL, PROTOCOL_TCP, seqNum, &sendPayload, PACKET_MAX_PAYLOAD_SIZE);

            seqNum++;
            sendWithTimerPing(&sendPackage);
            return;
        }
   }

   command error_t Transport.receive(pack* package) {
      TCP_packet_t *payload = (TCP_packet_t*) package -> payload;


      uint16_t tempSequenceNum;
      socket_storage_t *socket;
      socket_addr_t tempAddr;
      TCPpacket_t *payload = (TCPpacket_t*)package->payload;

      socket_addr_t socketAddress = assignTempAddress(payload -> src,
                                                      payload -> dest,
                                                      package -> src,
                                                      package -> dest);
      uint8_t socketLocation = -1; // yeet
      uint8_t i;

      switch (payload -> flag) {
         case SYN :
            dbg("Project3TGen", "SYN packet arrived from node://%d:%d\n", package->src, TCPpayload->destPort);

            socketLocation = call LiveSocketList.checkIfPortIsListening(payload -> destPort);
            if (socketLocation != -1) {
               call Connections.pushback(tempAddr);
               return SUCCESS;
            }

            dbg("Project3TGen", "Could not find listening port\n");
            return FAIL;
            break;

         case SYN_ACK :
            dbg("Project3TGen", "SYN_ACK packet arrived from node://%d:%d\n", package->src, TCPpayload->destPort);

            socketLocation = call LiveSocketList.search(&tempAddr, SOCK_SYN_SENT);

            if (socketLocation != -1) {

               socket = call LiveSocketList.getFd(socketLocation);
               socket -> state = SOCK_ESTABLISHED;

               makeTCPPack(&sendPayload, searchResultSocket->sockAddr.srcPort, searchResultSocket->sockAddr.destPort, 0, ACK, 0, payload->data, TCP_MAX_DATA_SIZE);

               makePack(&sendPackage, searchResultSocket->sockAddr.srcAddr, searchResultSocket->sockAddr.destAddr, MAX_TTL, PROTOCOL_TCP, seqNum, &sendPayload, PACKET_MAX_PAYLOAD_SIZE);

               seqNum++;
               sendWithTimerPing(&sendPackage);
               return SUCCESS;
            }

            return FAIL;
            break;

         case ACK :
            dbg("Project3TGen", "ACK packet arrived from node://%d:%d\n", package->src, TCPpayload->destPort);
            socketLocation = call LiveSocketList.search(&tempAddr, SOCK_ESTABLISHED);

            if (socketLocation != -1) {
                searchResultSocket = call LiveSocketList.getFd(socketLocation);
                searchResultSocket -> state = SOCK_FIN_WAIT;
                call Transport.write(call LiveSocketList.getFd(socketLocation), FIN);

                return SUCCESS;
            }

            socketLocation = call LiveSocketList.search(&tempAddr, SOCK_SYN_SENT);

            if (socketLocation != -1) {
                searchResultSocket = call LiveSocketList.getFd(socketLocation);
                searchResultSocket -> state = SOCK_ESTABLISHED;

                return SUCCESS;
            }

            // if we're waiting for a fin
            socketLocation = call LiveSocketList.search(&tempAddr, SOCK_FIN_WAIT);

            if (socketLocation != -1) {
                return SUCCESS;
            }

            return FAIL;

            break;

         case DATA :
            dbg("Project3TGen", "DATA packet arrived from node://%d:%d\n", package->src, TCPpayload->destPort);

            socketLocation = call LiveSocketList.search(&tempAddr, SOCK_ESTABLISHED);
            if (socketLocation != -1) {

                call WindowManager.receiveData(call LiveSocketList.getFd(socketLocation), payload);

                call Transport.write(call LiveSocketList.getFd(socketLocation), ACK);
                return SUCCESS;
            }

           socketLocation = call LiveSocketList.search(&tempAddr, SOCK_SYN_SENT);

           if (socketLocation != -1) {
              searchResultSocket = call LiveSocketList.getFd(socketLocation);
              searchResultSocket->state = SOCK_ESTABLISHED;
           }

            return FAIL;

            break;

         case FIN :
            dbg("Project3TGen", "FIN packet arrived from node://%d:%d\n", package->src, TCPpayload->destPort);

            // there are 3 cases we have for FIN, if the socket is established, if the socket is waiting to close, and if the socket is closed

            socketIndex = call LiveSocketList.search(&tempAddr, SOCK_ESTABLISHED);

            if (socketIndex != -1) {
                searchResultSocket = call LiveSocketList.getStore(socketIndex);
                if (searchResultSocket->lastByteRec >= TCPpayload->sequenceNum) {
                    searchResultSocket->state = SOCK_CLOSE_WAIT;

                    call WindowManager.readData(call LiveSocketList.getFd(socketIndex));
                    // send a fin_ack to close the client side connection
                    call Transport.write(call LiveSocketList.getFd(socketIndex), FIN_ACK);
                }
                return SUCCESS;
            }

            // Check if we're closing the socket
            socketIndex = call LiveSocketList.search(&tempAddr, SOCK_CLOSE_WAIT);

            if (socketIndex != -1) {
                searchResultSocket = call LiveSocketList.getStore(socketIndex);
                searchResultSocket->state = SOCK_CLOSED;

                dbg("Project3TGen", "Connection Closed\n");
                return SUCCESS;
            }

            // Check if the socket is closed
            socketIndex = call LiveSocketList.search(&tempAddr, SOCK_CLOSED);

            if (socketIndex != -1) {
                searchResultSocket = call LiveSocketList.getStore(socketIndex);
                call Transport.TCPSend(call LiveSocketList.getFd(socketIndex), FIN_ACK);

                return SUCCESS;
            }

            dbg("Project3TGen", "Error: connection failed\n");
            return FAIL;
            break;


         case FIN_ACK :
            dbg("Project3TGen", "FIN_ACK packet arrived from node://%d:%d\n", package->src, TCPpayload->destPort);

            // check if the socket is waiting to end
            socketIndex = call LiveSocketList.search(&tempAddr, SOCK_FIN_WAIT);

            if (socketIndex != -1) {
                call Transport.TCPSend(call LiveSocketList.getFd(socketIndex), FIN);
                searchResultSocket = call LiveSocketList.getStore(socketIndex);
                searchResultSocket->state = SOCK_CLOSED;
                dbg("Project3TGen", "Connection Closed\n");
                return SUCCESS;
            }

            dbg("Project3TGen", "Error: connection failed\n");
            return FAIL;

            break;

         default :
            return FAIL;
      }
   }

   command error_t Transport.close(socket_t fd) {
      socket_storage_t* socket;

      if (call LiveSocketList.contains(fd)) {
          // send a DIE
      }
   }

   command error_t Transport.listen(socket_t fd) {
      socket_storage_t* socket;

      if (call LiveSocketList.contains(fd)) {
         socket = call LiveSocketList.get(fd);
         socket -> state = SOCK_LISTEN;

         return SUCCESS;
      } else {
         dbg("Project3TGen", "Socket not found\n");
         return FAIL;
      }
   }

   command error_t Transport.release(socket_t fd) {

   }

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, TCPpacket_t *payload, uint8_t length) {
     Package->src = src;
     Package->dest = dest;
     Package->TTL = TTL;
     Package->seq = seq;
     Package->protocol = protocol;
     memcpy(Package->payload, payload, length);
  }

  void makeTCPPack(TCP_packet_t *Package, uint8_t srcPort, uint8_t destPort, uint16_t seq, uint8_t flag, uint8_t window, uint8_t *data, uint8_t length) {
     Package->src = src;
     Package->dest = dest;
     Package->seq = seq;
     Package->flag = flag;
     Package->window = window;
     memcpy(Package->data, data, length);
  }

}
