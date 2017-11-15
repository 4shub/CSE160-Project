#include "../../includes/window_info.h"


window_info_t generateNewWindowDetails(uint16_t size, uint16_t prevValue) {
   window_info_t info;
                 info.size = size;
                 info.prev = prevValue;

                 // CONSTANTS
                 info.completed            = WINDOW_DEFAULT_STATUS;
                 info.dataTransfer         = WINDOW_DEFAULT_DATA_IN_TRANSFER;
                 info.maxDataTransfer      = WINDOW_DEFAULT_MAX_DATA_IN_TRANSFER;
                 info.timeout              = WINDOW_DEFAULT_TIMEOUT;
                 info.synTimeout           = WINDOW_DEFAULT_TIMEOUT;
                 info.window               = WINDOW_DEFAULT_VALUE;
                 info.bytesInStream        = WINDOW_DEFAULT_BYTE_STREAM;

   return info;
}


module WindowManagerC {
   provides interface WindowManager;

   uses interface Hashmap<socket_storage_t> as SocketPointerMap;
   uses interface Hashmap<window_info_t> as WindowInfoList;
}

implementation {

   socket_storage_t* socket;

   // init buffer by creating the window information
   command void WindowManager.init(socket_t fd) {
      window_info_t info;

      uint16_t BUFFER_DATA_CAP = SOCKET_SEND_BUFFER_SIZE / 2;
      uint16_t tempBufferData[BUFFER_DATA_CAP + 1];
      uint16_t lastByte;

      uint8_t tempBufferToSend[SOCKET_SEND_BUFFER_SIZE];
      uint8_t lastByteAckIndex;
      uint8_t bufferLength;

      if (call SocketPointerMap.contains(fd)) {
         socket = call SocketPointerMap.get(fd);
         info = call WindowInfoList.get(fd);

         if (info.completed) {
            return; // done
         }

         // Data is being inserted into this buffer
         if (socket->lastByteWritten == 0) {

            int i;
            for (i = 0; i < BUFFER_DATA_CAP; i++) {
               tempBufferData[i] = i;
            }

            memcpy(socket->sendBuff, &tempBufferData, SOCKET_SEND_BUFFER_SIZE);

            socket->lastByteWritten = SOCKET_SEND_BUFFER_SIZE;

            info.prevValue = BUFFER_DATA_CAP - 1;
            if (SOCKET_SEND_BUFFER_SIZE - 1 > info.size) {
               info.completed = TRUE;
            }

            call WindowInfoList.insert(fd, info);

            return;
         }

         // end of buffer
         if (socket->lastByteSent > socket -> lastByteWritten - TCP_MAX_DATA_SIZE) {

            bufferLength = 1 + socket -> lastByteWritten - socket -> lastByteAck;

            lastByteAckIndex = SOCKET_SEND_BUFFER_SIZE - bufferLength;

            memcpy((uint8_t*)&tempBufferToSend, socket->sendBuff + lastByteAckIndex, bufferLength);

            memcpy(socket->sendBuff, &tempBufferToSend, bufferLength);

            int i;
            for (i = 1; i <= SOCKET_SEND_BUFFER_SIZE / 2; i++) {
               tempBufferData[curIndex - 1] = i + info.prevValue;
            }


            info.prevValue += lastByteAckIndex / 2;

            memcpy(socket->sendBuff + bufferLength, &tempBufferData, lastByteAckIndex);
            socket->lastByteWritten += lastByteAckIndex;

            if (socket->lastByteWritten > info.size) {
               info.completed = TRUE;
            }

            call WindowInfoList.insert(fd, info);

            return;
         }



        return;
      }
   }

   // get an ACK
   command uint8_t WindowManager.recieveACK(socket_t fd, TCP_packet_t* payload) {
      window_info_t info;

      if (call SocketPointerMap.contains(fd)) {
         socket = call SocketPointerMap.get(fd);
         info = call WindowInfoList.get(fd);
         info.dataTransfer -= 1;

         if (payload -> sequenceNum == socket -> lastByteAck) {
            if (info.synTimeout > 0) {
               info.synTimeout -= 1;
            }
            if (info.synTimeout == 0) {
               socket->lastByteSent = socket->lastByteAck - 1;
            }
         } else {
            info.synTimeout = 5;
         }

         info.window = payload->window;
         socket->lastByteAck = payload->sequenceNum;

         call WindowInfoList.insert(fd, info);

         if (socket->lastByteAck >= info.size) {
            return FIN;
         }

         return DATA;
      }
      return NULL;
   }

   // get data
   command error_t WindowManager.receiveData(socket_t fd, TCP_packet_t* payload) {
      int i;
      window_info_t info;
      uint8_t amountReceived;
      uint16_t firstBufferByte;
      uint16_t currentPayloadIndex;

      if (call SocketPointerMap.contains(fd)) {
         socket = call SocketPointerMap.get(fd);
         info = call WindowInfoList.get(fd);

         if (payload->sequenceNum - socket->lastByteRec <= TCP_MAX_DATA_SIZE) {
            amountReceived = payload->sequenceNum - socket->lastByteRec;

            // Byte number at index 0 of recbuffer
            firstBufferByte = socket->lastByteRead;

            currentPayloadIndex = payload->sequenceNum - firstBufferByte - amountReceived;

            memcpy(socket->recBuff + currentPayloadIndex, payload->data, amountReceived);

            socket->lastByteRec = payload->sequenceNum;
            socket->lastByteExpected = payload->sequenceNum + 1;

            return SUCCESS;
         }

         return FAIL;
      }
   }

   command error_t WindowManager.initData(socket_t fd, uint8_t* data, uint16_t* sequenceNum) {
        int curIndex;
        int EffectiveWindow;
        uint8_t dataLength;
        uint8_t lastByteSentIndex;
        uint8_t lastByteAckIndex;
        window_info_t info;

        // if the fd does not exist, we die
        if (!call Hashmap.contains(fd)) {
            return FAIL;
        }

        socket = call Hashmap.get(fd);
        info = call WindowInfoList.get(fd);

        EffectiveWindow = info.window - (socket->lastByteSent - socket->lastByteAck);

        if (EffectiveWindow <= 0) {
            info.synTimeout -= 1;

            if (info.synTimeout == 0) {
               if (socket->lastByteAck == 0) {
                  socket->lastByteSent = 0;
               } else {
                  socket->lastByteSent = socket->lastByteAck - 1;
               }

               info.dataTransfer = 0;
               info.synTimeout = 5;
            }
            call WindowInfoList.insert(fd, info);

            return FAIL;
        }

        if(socket->lastByteAck >= info.size) {
            return FAIL;
        }

        lastByteSentIndex = SOCKET_SEND_BUFFER_SIZE - (socket->lastByteWritten - socket->lastByteSent);
        lastByteAckIndex = SOCKET_SEND_BUFFER_SIZE - (socket->lastByteWritten - socket->lastByteAck + 1);

        if (lastByteSentIndex + TCP_MAX_DATA_SIZE > SOCKET_SEND_BUFFER_SIZE) {
            socket->lastByteSent = socket->lastByteAck;
            return FAIL;
        }

        if (socket->lastByteSent + TCP_MAX_DATA_SIZE > info.size) {
            dataLength = info.size - socket->lastByteSent;
        } else {
            dataLength = TCP_MAX_DATA_SIZE;
        }

        memcpy(data, socket->sendBuff + lastByteSentIndex, dataLength);

        socket->lastByteSent += dataLength;
        *sequenceNum = socket->lastByteSent;

        info.dataTransfer++;
        call WindowInfoList.insert(fd, info);

        return SUCCESS;
    }

   command void WindowManager.readData(socket_t fd) {

      int bytesInBuffer;
      uint16_t tempBuff1[5];
      uint8_t tempBuff2[10];
      uint8_t tempBuff3[SOCKET_RECEIVE_BUFFER_SIZE];

      if (call Hashmap.contains(fd)) {
         socket = call Hashmap.get(fd);

         bytesInBuffer = (socket -> lastByteExpected - 1) - socket -> lastByteRead;
         if (socket->state == SOCK_CLOSE_WAIT) {
            int i;
            for (i = 0; i < bytesInBuffer; i++) {
               tempBuff2[i] = socket -> recBuff[i];
            }

            memcpy(&tempBuff1, &tempBuff2, bytesInBuffer);

            socket->lastByteRead += bytesInBuffer;
            return
         }

         if (10 < bytesInBuffer) {
            for (i = 0; i < 10; i++) {
                  tempBuff2[i] = socket -> recBuff[i]; // + 1];
            }

            memcpy(&tempBuff1, &tempBuff2, 10);

            socket->lastByteRead += 10;

            for (i = 0; i < SOCKET_RECEIVE_BUFFER_SIZE - 10; i++) {
               socket->recBuff[i] = socket -> recBuff[i + 10];
            }
         }
      }
   }

   command void WindowManager.setWindowInfo(socket_t fd, uint16_t size) {
      window_info_t temp = newInfo(size, 0);
      call WindowInfoList.insert(fd, temp);
   }

}
