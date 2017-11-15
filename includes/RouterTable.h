//Author:
#ifndef ROUTER_TABLE_ROW_H
#define ROUTER_TABLE_ROW_H

typedef struct RouterTableRow {
    uint16_t nodeName;
    uint16_t nextNode;
    uint16_t distance;
} RouterTableRow;

#endif /* ROUTER_TABLE_ROW_H */
