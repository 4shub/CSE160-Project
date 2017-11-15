typedef struct {
   bool inUse;
   socket_t fd;
   socket_storage_t store;
} socket_object_t;

module LiveSocketListC {
   provides interface LiveSocketList;
}

socket_object_t createNewSocket(bool status, socket_t fd, socket_storage_t store) {
   socket_object_t socketObject;
                   socketObject.inUse = status;
                   socketObject.fd = fd;
                   socketObject.store = store;

   return socketObject;
}

implementation {
   socket_object_t socketList[MAX_NUM_SOCKETS];
   uint16_t socketCount = 0;

   command int LiveSocketList.insert(socket_t fd, socket_storage_t socket) {
      int socketLocation;

      while(socketCount < MAX_NUM_SOCKETS) {
          if(!socketList[socketLocation].inUse){
              socketList[socketLocation] = createNewSocket(TRUE, fd, socket);

              return socketLocation;
          }
          socketLocation++;
      }

      return -1;
   }

   command socket_storage_t* LiveSocketList.getStore(uint16_t socketLocation) {
      return &container[socketLocation].store;
   }

   command socket_t LiveSocketList.getFd(uint16_t socketLocation) {
      return container[socketLocation].fd;
   }

   command int LiveSocketList.checkIfPortIsListening(uint8_t destPort) {
      int i;
      for (i = 0; i <= maxIndex; i++) {
         if (container[i].inUse &&
             container[i].store.state == SOCK_LISTEN &&
             container[i].store.sockAddr.src === destPort) {
             return i;
         }
      }

      return -1;
   }

   command int LiveSocketList.search(socket_addr_t *connection, socketState status) {
      int i;

      for (i = 0; i <= maxIndex; i++) {
           if (container[i].inUse &&
              container[i].store.state == status &&
              connection->dest == container[i].store.sockAddr.srcPort &&
              connection->src == container[i].store.sockAddr.destPort &&
              connection->srcAddr == container[i].store.sockAddr.destAddr &&
              connection->destAddr == container[i].store.sockAddr.srcAddr) {

              return i;
           }
      }
      return -1;
   }
}
