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
#include "includes/TCP_packet.h"
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
    TransportP.Sender -> SimpleSendC;

    components WindowManagerP;
    Node.WindowManager -> WindowManagerP;
    TransportP.WindowManager -> WindowManagerP;

    components new ListC(socket_addr_t, 256) as ListC1;
    Node.Connections -> ListC1;
    TransportP.Connections -> ListC1;

    components new HashmapC(window_info_t, 256) as HashmapC4;
    WindowManagerP.WindowInfoList -> HashmapC4;

    components LiveSocketListC;
    Node.LiveSocketList -> LiveSocketListC;
    TransportP.LiveSocketList -> LiveSocketListC;

    components new HashmapC(RouterTableRow, 256) as HashmapC1;
    Node.RouterTable -> HashmapC1;
    TransportP.RouterTable -> HashmapC1;

    components new HashmapC(socket_storage_t*, MAX_SOCKET_COUNT) as HashmapC3;
    Node.SocketPointerMap -> HashmapC3;
    TransportP.SocketPointerMap -> HashmapC3;
    WindowManagerP.SocketPointerMap -> HashmapC3;

    components RandomC;
    TransportP.Random -> RandomC;
}
