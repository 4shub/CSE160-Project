interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort, uint8_t *transfer);
   event void setTestServer(uint8_t port);
   event void stopTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort);
   event void setAppServer();
   event void setAppClient();
}
