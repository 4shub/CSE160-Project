# Project 1
Project one's purpose is to create software that enables discovery of all nodes in a particular system by flooding. Flooding itself is the process in which an nodes will send packets to outgoing nodes until it hits an endpoint

## Utilization and Architecture
For this project, we will be using a hash table to efficiently store the identifiers of nodes in any network topology. The way this will work is that we will be implementing an ACK message to each future node from the Origin. The hash-map itself will only exist on the origin and will collect node information every time a new node has been discovered. This way all data is centralized in one particular area (our router node). The hash-map is stuctured so that every child node will exist as a child of a particular hash. This will have a form of protection so we can avoid having multiple of the same children exist on the map. (Per-say if node 2 can be reached from node 1 and node 3, we can resend an ACK that will just reinsert itself into the hashmap).

Way it works -> we know the total amount of nodes, so all we need to do is keep finding a larger node to traverse to and give it an appropriate TTL (let's say in this case 250ms since we're dealing with a small interface). If there is no node that can be found, we shall go to the first discovered node and repeat the process.

## Programmatic layout


```
NodeExplorer
  Node1 -> Node2 = found
  Node1 -> Node3 = found
  Node1 -> Node4 = MAX_TTL_EXCEEDED (write a callback)
  Node2 -> Node1 = MAX_TTL_EXCEEDED
  Node2 -> Node2 = Ignore
  Node2 -> Node3 = found
  Node2 -> Node4 = MAX_TTL_EXCEEDED
  Node3 -> Node1 = MAX_TTL_EXCEEDED (Start from initial node, but keep going until 1 after the node)
  Node3 -> Node2 = found
  Node3 -> Node4 = found
  Node3 -> Node5 = MAX_TTL_EXCEEDED
```

## Discussion Questions

1. Describe a pro and a con of using event driven programing.

Pro: If you follow event driven programing, you are able to easily build a system that runs asychronously since every event can be its own functions

Con: Not as good as doing a combination of Test Based Event Driven Event Programming where we can have test cases as the foundation for every user action.


2. Flooding includes a mechanism to prevent packets from circulating indefinitely, and the TTL field provides another mechanism. What is the benefit of having both? What would happen if we only had flooding checks? What would happen if we had only TTL checks?

If we only had flooding checks, we could not check if a server is down since flooding would still recognize the network, if we didn't have flooding checks we would have to set a hard limit on how many nodes we have to keep exploring.

3. When using the flooding protocol, what would be the total number of packets sent/received by all the nodes in the best case situation? Worse case situation? Explain the topology and the reasoning behind each case.

Best Case: 2*nodes - we have all nodes that are just one neighbor apart
Worst Case: nodes^2 - all nodes are neighbors of each other

4. Using the information gathered from neighbor discovery, what would be a better way of accomplishing multi-hop communication?

We can do multihop by traveling to closest neighbor by number first using our dictionary instead of flooding every node.

5. Describe a design decision you could have made differently given that you can change the provided skeleton code and the pros and cons compared to the decision you made?

I think we can add the timer prebuilt in the skeleton code just because TTL will obviously be included in the program.
