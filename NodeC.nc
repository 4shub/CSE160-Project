/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"
#include "includes/socket.h"
#include "includes/RouterTable.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;



    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components new HashmapC(uint16_t, 256) as HashmapC2;
    Node.MessageStorageExplored -> HashmapC2;

    components new TimerMilliC() as packageTimerC;
    Node.packageTimer -> packageTimerC;

    components new TimerMilliC() as packageTimerC2;
    Node.neighborExplorerTimer -> packageTimerC2;

    components new TimerMilliC() as packageTimerC3;
    Node.ClientDataTimer -> packageTimerC3;

    components new TimerMilliC() as packageTimerC4;
    Node.AttemptConnection -> packageTimerC4;

    components TransportP;
    Node.Transport -> TransportP;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;
    Node.Transport -> SimpleSendC;

    components new ListC(socket_addr_t, 256) as ListC1;
    Node.Connections -> ListC1;
    TransportC.WindowManager -> WindowManagerC;

    components WindowManagerC;
    Node.WindowManager -> WindowManagerC;
    TransportC.WindowManager -> WindowManagerC;

    components LiveSocketList;
    Node.LiveSocetList -> LiveSocketList;
    TransportC.LiveSocetList -> LiveSocketList;

    components new HashmapC(RouterTableRow, 256) as HashmapC1;
    Node.RouterTable -> HashmapC1;
    TransportC.RouterTable -> HashmapC1;

    components new HashmapC(socket_storage_t, MAX_NUM_SOCKETS) as HashmapC3;
    Node.SocketPointerMap -> HashmapC3;
    TransportC.SocketPointerMap -> HashmapC3;
    WindowManagerC.SocketPointerMap -> HashmapC3;
}
