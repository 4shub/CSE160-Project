/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */



#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/socket.h"
#include "includes/TCP_packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/RouterTable.h"
#include "includes/LinkState.h"
#include "includes/chat.h"



module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;

   uses interface Hashmap<RouterTableRow> as RouterTable;

   uses interface Hashmap<uint16_t> as MessageStorageExplored; // stores unique message ids to prevent overflows for exploration

   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface Timer<TMilli> as packageTimer;

   uses interface Timer<TMilli> as neighborExplorerTimer;

   uses interface Timer<TMilli> as ClientDataTimer;

   uses interface Timer<TMilli> as AttemptConnection;

   uses interface List<socket_addr_t> as Connections;

   uses interface Hashmap<uint8_t*> as Users;

   uses interface Transport;

   uses interface WindowManager;

   uses interface LiveSocketList;

   uses interface Hashmap<socket_storage_t*> as SocketPointerMap;
}

implementation{


   pack sendPackage;
   pack ackPackage;

   uint8_t * currentUser;
   LinkState currentNeighbors;

   int MAX_NODE_COUNT = 17;
   uint8_t returned = 0;
   uint8_t lastDestination = 1;
   uint8_t seqNum = 0;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);


   void sendWithTimerDiscovery(pack Package, uint16_t destination);
   void sendWithTimerPing(pack *Package);

   void sendACKMessage(uint16_t origin, uint8_t ackProtocol);

   void adjustRoutingTable(uint16_t origin, LinkState partnerNeighbors);

   void createNewRouterTableRow(uint16_t currentNode, uint16_t origin, uint16_t distance);

   void adjustRouterTableContents(uint16_t originNode, LinkState partnerNeighbors, uint16_t distance);

   uint16_t ignoreSelf(uint16_t destination);

   uint16_t sendInitial(uint16_t initial);

   uint16_t generateUniqueMessageHash(uint16_t payload, uint16_t destination, uint16_t sequence);

   uint16_t findNextSequenceNumber(uint16_t payload, uint8_t destination);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");

         // METHOD: Start finding neighbors
         call neighborExplorerTimer.startPeriodic(5000);
      } else {
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}


   // Message gets recieved
   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

      pack* recievedPackage = (pack*) payload; // park payload

      uint16_t messageHash = generateUniqueMessageHash(recievedPackage -> payload, recievedPackage -> dest, recievedPackage -> seq);



      if (recievedPackage -> protocol == PROTOCOL_TCP) {
        if (recievedPackage -> dest == TOS_NODE_ID) {
            // arrived
            dbg(NEIGHBOR_CHANNEL, "Client data recieved from: %i\n", recievedPackage -> src);

            call Transport.receive(recievedPackage);

            return msg;
        }

        recievedPackage -> TTL = recievedPackage -> TTL - 1;

        if (recievedPackage -> TTL > 0) {
            makePack(&sendPackage,
                      TOS_NODE_ID,
                      recievedPackage -> dest,
                      recievedPackage -> TTL,
                      0,
                      recievedPackage -> seq,
                      recievedPackage -> payload,
                      PACKET_MAX_PAYLOAD_SIZE);

            // SEND new Package
            sendWithTimerPing(&sendPackage);

            return msg;
        }

        dbg(NEIGHBOR_CHANNEL, "TCP Timed out");
        return msg;
      }

      // CASE: our Prootocol is for a normal message
      if(recievedPackage -> protocol == 0) {

        // CASE: If we arrive at the destination
        if(TOS_NODE_ID == recievedPackage -> dest && !call MessageStorageExplored.contains(messageHash)) {

            dbg(GENERAL_CHANNEL, "ARRIVED AT DESTINATION! YAY!\n\n");
            dbg(NEIGHBOR_CHANNEL, "Your message is: %s!\n\n\n", recievedPackage -> payload);

            call MessageStorageExplored.insert(messageHash, 1);

            return msg;
        }

        // CASE: If we don't at the destination
        if(len == sizeof(pack)) {
           // METHOD: Copy old package to new a new package, replacing the source ID with the current Node ID
           makePack(&sendPackage,
                     TOS_NODE_ID,
                     recievedPackage -> dest,
                     recievedPackage -> TTL,
                     0,
                     recievedPackage -> seq,
                     recievedPackage -> payload,
                     PACKET_MAX_PAYLOAD_SIZE);

           // SEND new Package
           sendWithTimerPing(&sendPackage);

           return msg;
        }

        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);

        return msg;
      } else if(recievedPackage -> protocol == 1) {
          // CASE: our Protocol is for a ACK Message
          returned = 1; // we've returned!

          // METHOD: We have arrived at our destination, we don't need to make this message exist more
          if(recievedPackage -> seq == 1) {
              return msg;
          }

          // METHOD: We have not arrived yet at our destination, please search more
          if (currentNeighbors.nodes[recievedPackage -> src] != 1) {
            dbg(NEIGHBOR_CHANNEL, "FOUND NEW NEIGHBOR %i!\n", recievedPackage -> src);

            currentNeighbors.nodes[recievedPackage -> src] = 1;

          }

          // let's explore the next node

          sendWithTimerDiscovery(sendPackage, ignoreSelf(recievedPackage -> src + 1));

          return msg;
      } else if(recievedPackage -> protocol == 2) {
          // CASE: our Protocol is for link state movement
          //LinkState neighborLinkState = (LinkState*) recievedPackage -> payload;

          adjustRoutingTable(recievedPackage -> src, *((LinkState*) recievedPackage -> payload));

          sendACKMessage(recievedPackage -> src, 0);

          return msg;
      }
   }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload) {

      dbg(NEIGHBOR_CHANNEL, "STARTING TO PING FOLLOWING: %i!\n", (destination));

      makePack(&sendPackage,
                TOS_NODE_ID,
                destination,
                150,
                0, // protocol
                seqNum, // sequence
                payload,
                PACKET_MAX_PAYLOAD_SIZE);

      seqNum = seqNum + 1;
      sendWithTimerPing(&sendPackage);
   }

   uint16_t sendInitial(uint16_t initial){
     if( initial == 1) {
       return 2;
     } else {
       return 1;
     }
   }

   uint16_t ignoreSelf(uint16_t destination){
     if( TOS_NODE_ID == destination) {
       return destination + 1;
     }

     return destination;
   }


   void sendACKMessage(uint16_t origin, uint8_t arrivedAtDestination) {

     dbg(GENERAL_CHANNEL, "SENDING FROM: %i to %i\n", TOS_NODE_ID, origin);

     makePack(&ackPackage,
              TOS_NODE_ID,
              origin,
              500,
              1,
              arrivedAtDestination,
              'ACK',
              PACKET_MAX_PAYLOAD_SIZE);

     call Sender.send(ackPackage, origin);
   }

   void sendWithTimerDiscovery(pack Package, uint16_t destination) {
     returned = 0;

     lastDestination = destination;
     call packageTimer.startOneShot(500);
     call Sender.send(Package, destination);
   }

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


   uint16_t generateUniqueMessageHash(uint16_t payload, uint16_t destination, uint16_t sequence){
       return payload + ((sequence + 1) * destination);
   }

   event void packageTimer.fired(){
     if( returned == 0 ) {
       dbg(GENERAL_CHANNEL, "Can't find destination \n");

       lastDestination = lastDestination + 1;
       call Sender.send(sendPackage, lastDestination);
     }
 }


   event void neighborExplorerTimer.fired(){
      pack discoveryMessage;

     // METHOD: think-pair share neighbors and create map
     uint8_t nodeToDiscover = ignoreSelf(1);
     uint8_t maxNodeCount = MAX_NODE_COUNT;

     while(nodeToDiscover < maxNodeCount) {
         makePack(&discoveryMessage,
                  TOS_NODE_ID,
                  nodeToDiscover,
                  500,
                  2,
                  0,
                  &currentNeighbors,
                  PACKET_MAX_PAYLOAD_SIZE);

        sendWithTimerDiscovery(discoveryMessage, nodeToDiscover);

        nodeToDiscover++;
     }
   }

  void createNewRouterTableRow(uint16_t currentNode, uint16_t originNode, uint16_t distance) {
      RouterTableRow row;
                     row.nodeName = currentNode;
                     row.nextNode = originNode;
                     row.distance = distance;

      call RouterTable.insert(currentNode, row);
  }



  void adjustRouterTableContents(uint16_t originNodeID, LinkState neighbors, uint16_t distanceToThisNode) {
      int currentNodeID = 1;

      // adjust partners of partners
      // TODO: fix max
      while(currentNodeID < MAX_NODE_COUNT){
          if(neighbors.nodes[currentNodeID] == 1) {

              if(!call RouterTable.contains(currentNodeID)) {
                  createNewRouterTableRow(currentNodeID, originNodeID, distanceToThisNode);
              } else {
                  RouterTableRow currentRow = call RouterTable.get(currentNodeID);

                  if(currentRow.distance > distanceToThisNode) {
                      call RouterTable.remove(currentNodeID);

                      createNewRouterTableRow(currentNodeID, originNodeID, distanceToThisNode);
                  }
              }
          }

          currentNodeID++;
      }
  }

  void adjustRoutingTable(uint16_t originNodeID, LinkState partnerNeighbors) {
      adjustRouterTableContents(TOS_NODE_ID, currentNeighbors, 1);
      adjustRouterTableContents(originNodeID, partnerNeighbors, 2);
  }

   event void CommandHandler.printNeighbors(){
       int i = 1;

       while(i < sizeof(currentNeighbors.nodes)/sizeof(uint16_t)) {
           if(currentNeighbors.nodes[i] == 1) {
               dbg(NEIGHBOR_CHANNEL, "Neighbor: %i\n", i);
           }
           i++;
       }
   }

   event void CommandHandler.printRouteTable(){
       int i = 1;

       while(i < MAX_NODE_COUNT) {
           if(call RouterTable.contains(i)) {
               RouterTableRow row = call RouterTable.get(i);

               dbg(NEIGHBOR_CHANNEL, "NodeName: %i, NextNode: %i, Distance: %i\n", row.nodeName, row.nextNode, row.distance);
           }

           i++;
       }
   }

   event void CommandHandler.printLinkState(){
       signal CommandHandler.printNeighbors();
   }

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint8_t port){
        socket_t fd = call Transport.socket();
        socket_addr_t socketAddress;

        dbg(NEIGHBOR_CHANNEL,"Init server at port-%d\n", port);

        if (fd != NULL_SOCKET) {
            socketAddress.srcAddr = TOS_NODE_ID;
            socketAddress.srcPort = port;
            socketAddress.destAddr = 0;
            socketAddress.destPort = 0;

            if (call Transport.bind(fd, &socketAddress) == SUCCESS) {
                dbg(NEIGHBOR_CHANNEL,"socket %d binded to port-%d\n", fd, port);
                call Transport.listen(fd);
                call AttemptConnection.startPeriodic(1000);

                return;
            }

            dbg(NEIGHBOR_CHANNEL,"Server could not be set up\n");
            return;
       }

       dbg(NEIGHBOR_CHANNEL,"Server could not be set up\n");
       return;
   }

    event void AttemptConnection.fired() {
        socket_storage_t* tempSocket;
        uint32_t* socketKeys = call SocketPointerMap.getKeys();

        int i;
        // if we have connections on our server, we should accept this
        if (call Connections.size() > 0) {
            call Transport.accept();
        }

        // go through all the sockets we have we have
        for (i = 0; i < call SocketPointerMap.size(); i++) {
            tempSocket = call SocketPointerMap.get(socketKeys[i]);

            if (tempSocket -> state == SOCK_ESTABLISHED) {
                // read data
                call WindowManager.readData(socketKeys[i]);
            }
        }
    }

    event void CommandHandler.setTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort, uint8_t *transfer) {
        socket_storage_t temp;
        socket_addr_t socketAddress;
        socket_t fd = call Transport.socket();

        uint16_t *transferSize = (uint16_t*) transfer;

        dbg(NEIGHBOR_CHANNEL,"Init client at port-%d headed to node://%d:%d with content '%s'\n", srcPort, dest, destPort, transfer);

        socketAddress.srcAddr = TOS_NODE_ID;
        socketAddress.srcPort = srcPort;
        socketAddress.destAddr = dest;
        socketAddress.destPort = destPort;

        call Transport.bind(fd, &socketAddress);
        call Transport.connect(fd, &socketAddress);
        call WindowManager.setWindowInfo(fd, transferSize[0]);
        call ClientDataTimer.startPeriodic(2500);
   }

   event void ClientDataTimer.fired() {
        socket_storage_t* tempSocket;
        uint32_t* socketKeys = call SocketPointerMap.getKeys();

        int i;
        for (i = 0; i < call SocketPointerMap.size(); i++) {
           tempSocket = call SocketPointerMap.get(socketKeys[i]);

           if (tempSocket -> state == SOCK_ESTABLISHED) {
               dbg(NEIGHBOR_CHANNEL,"Connection established - Sending DATA\n");

              call WindowManager.init(socketKeys[i]);
              call Transport.write(socketKeys[i], DATA);

           } else if (tempSocket->state == SOCK_SYN_SENT) {
              if (tempSocket->timeout == 0) {
                 dbg(NEIGHBOR_CHANNEL,"Connection Failed - Retrying\n");

                 call Transport.connect(socketKeys[i], &tempSocket->sockAddr);
                 tempSocket -> timeout = 6;
              } else {
                 // lets keep retrying
                 tempSocket -> timeout -= 1;
              }

           } else if (tempSocket->state == SOCK_FIN_WAIT) {
              if (tempSocket->timeout == 0) {
                 dbg(NEIGHBOR_CHANNEL,"Connection Failed - Retrying\n");

                 call Transport.write(socketKeys[i], FIN);

                 tempSocket -> timeout = 6;
              } else {

                 // lets keep retrying
                 tempSocket -> timeout -= 1;
              }
           }
       }
    }

    event void CommandHandler.stopTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort) {
        socket_addr_t socketAddress;
        uint8_t socketIndex;

        socketAddress.srcAddr = TOS_NODE_ID;
        socketAddress.srcPort = srcPort;
        socketAddress.destAddr = dest;
        socketAddress.destPort = destPort;

        // find established socket and close it
        socketIndex = call LiveSocketList.search(&socketAddress, SOCK_ESTABLISHED);

        if (socketIndex != -1) {
            call Transport.close(call LiveSocketList.getFd(socketIndex));
        }
    }

   event void CommandHandler.startChatServer(){
       socket_t fd = call Transport.socket();
       socket_addr_t socketAddress;

       dbg(NEIGHBOR_CHANNEL,"Init server at port-%d\n", DEFAULT_CHAT_PORT);

       if (fd != NULL_SOCKET) {
           socketAddress.srcAddr = TOS_NODE_ID;
           socketAddress.srcPort = DEFAULT_CHAT_PORT;
           socketAddress.destAddr = 0;
           socketAddress.destPort = 0;

           if (call Transport.bind(fd, &socketAddress) == SUCCESS ) {
               dbg(NEIGHBOR_CHANNEL,"Chat server booted!\n");
               call Transport.listen(fd);
               call AttemptConnection.startPeriodic(1000);

               return;
           }

           dbg(NEIGHBOR_CHANNEL,"Server could not be set up\n");
           return;
       }

       dbg(NEIGHBOR_CHANNEL,"Server could not be set up\n");
       return;
   }

   event void CommandHandler.msg(uint8_t *message){
       socket_storage_t temp;
       socket_addr_t socketAddress;
       socket_t fd = call Transport.socket();
       uint16_t *transferSize = (uint16_t*) message;

       dbg(NEIGHBOR_CHANNEL,"To everyone: %s\n", message);

       socketAddress.srcAddr = TOS_NODE_ID;
       socketAddress.srcPort = DEFAULT_CHAT_PORT;
       socketAddress.destAddr = DEFAULT_CHAT_NODE;
       socketAddress.destPort = DEFAULT_CHAT_PORT;

       call Transport.bind(fd, &socketAddress);
       call Transport.connect(fd, &socketAddress);
       call WindowManager.setWindowInfo(fd, transferSize[0]);
       call ClientDataTimer.startPeriodic(2500);
       return;
   }


   event void CommandHandler.hello(uint8_t *username, uint8_t port){
       socket_storage_t temp;
       socket_addr_t socketAddress;
       socket_t fd = call Transport.socket();
       uint16_t *transferSize = (uint16_t*) username;

       dbg(NEIGHBOR_CHANNEL,"<%s> has entered\n", username);

       socketAddress.srcAddr = TOS_NODE_ID;
       socketAddress.srcPort = port;
       socketAddress.destAddr = DEFAULT_CHAT_NODE;
       socketAddress.destPort = DEFAULT_CHAT_PORT;

       call Transport.bind(fd, &socketAddress);
       call Transport.connect(fd, &socketAddress);
       call WindowManager.setWindowInfo(fd, transferSize[0]);
       call ClientDataTimer.startPeriodic(2500);
       return;
   }

   event void CommandHandler.whisper(uint8_t *username, uint8_t *message){
       socket_storage_t temp;
       socket_addr_t socketAddress;
       socket_t fd = call Transport.socket();

       uint16_t *transferSize = (uint16_t*) message;

       dbg(NEIGHBOR_CHANNEL,"<%s>: %s\n", username, message);

       socketAddress.srcAddr = TOS_NODE_ID;
       socketAddress.srcPort = DEFAULT_CHAT_PORT;
       socketAddress.destAddr = DEFAULT_CHAT_NODE;
       socketAddress.destPort = DEFAULT_CHAT_PORT;

       call Transport.bind(fd, &socketAddress);
       call Transport.connect(fd, &socketAddress);
       call WindowManager.setWindowInfo(fd, transferSize[0]);
       call ClientDataTimer.startPeriodic(2500);
       return;
   }

   event void CommandHandler.listUsers(){
       int i = 0;

       for(i = 0; i < 256; i++) {
           if (call Users.contains(i)) {
               dbg(NEIGHBOR_CHANNEL,"User: %d\n", call Users.get(i));
           }
       }
   }

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }


}
