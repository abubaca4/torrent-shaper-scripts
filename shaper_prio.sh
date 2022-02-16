#!/bin/sh

# kernel modules load
modprobe sch_fq_codel
modprobe cls_u32

## settings

# should be with your external ip check it by ifconfig or ip a show
WAN_INTF=eth2.2

# should be local bridge with your switch ports and wifi
LAN_INTF=br0

# is torrent filtering by mac and port enabled(true)
enable_mac_filter=false

# mac(without :) and port for filter torrents
mac_port_list="629899F3B532|51413 00D86139729B|20000 00241D833036|30000"

# protocol ipv6 filter not work in PADAVAN with kernel 3.4.113 so it option to diasble ipv6 filter(true for enable)
enable_ipv6_torrent=false

# is torrent filtering by ip and port enabled(true)
enable_ip_filter=true

# ip and port for filter torrents
ip_port_list="192.168.8.39|51413 192.168.8.61|20000 192.168.8.44|30000"

## end settings

# remove default
tc qdisc del dev $WAN_INTF root > /dev/null 2>&1
# outcoming traffic
tc qdisc add dev $WAN_INTF root handle 1: prio bands 3 priomap 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
tc qdisc add dev $WAN_INTF parent 1:1 handle 10: fq_codel limit 10240
tc qdisc add dev $WAN_INTF parent 1:2 handle 20: fq_codel limit 10240
tc qdisc add dev $WAN_INTF parent 1:3 handle 30: pfifo limit 10240

# remove default
tc qdisc del dev $LAN_INTF root > /dev/null 2>&1
# incoming traffic
tc qdisc add dev $LAN_INTF root handle 1: prio bands 3 priomap 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
tc qdisc add dev $LAN_INTF parent 1:1 handle 10: fq_codel limit 10240
tc qdisc add dev $LAN_INTF parent 1:2 handle 20: fq_codel limit 10240
tc qdisc add dev $LAN_INTF parent 1:3 handle 30: pfifo limit 10240

# trafic filters
###HIGH PRIO
## outcoming
#ICMP
tc filter add dev $WAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 1 0xff flowid 1:1
#ACK
tc filter add dev $WAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 6 0xff match u8 0x05 0x0f at 0 match u16 0x0000 0xffc0 at 2 match u8 0x10 0xff at 33 flowid 1:1
#DNS
tc filter add dev $WAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 17 0xff match ip sport 53 0xffff flowid 1:1
#VOIP
tc filter add dev $WAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0x68 0xff match ip protocol 11 0xff flowid 1:1
tc filter add dev $WAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0xb8 0xff match ip protocol 11 0xff flowid 1:1
#TOS
tc filter add dev $WAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0x10 0xff flowid 1:1
#NTP
tc filter add dev $WAN_INTF parent 1: protocol ip prio 2 u32 match ip protocol 17 0xff match ip sport 123 0xffff flowid 1:1
## incoming
#ICMP
tc filter add dev $LAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 1 0xff flowid 1:1
#ACK
tc filter add dev $LAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 6 0xff match u8 0x05 0x0f at 0 match u16 0x0000 0xffc0 at 2 match u8 0x10 0xff at 33 flowid 1:1
#DNS
tc filter add dev $LAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 17 0xff match ip sport 53 0xffff flowid 1:1
#VOIP
tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0x68 0xff match ip protocol 11 0xff flowid 1:1
tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0xb8 0xff match ip protocol 11 0xff flowid 1:1
#TOS
tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0x10 0xff flowid 1:1
#IPTV
#tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip protocol 17 0xff match ip dst 224.0.0.0/3 flowid 1:1
#NTP
tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip protocol 17 0xff match ip sport 123 0xffff flowid 1:1

###MED PRIO Default
# all other traffic

###LOW PRIO
# filter by mac and port for torrents
if [ "$enable_mac_filter" = true ] ; then
    for e in $mac_port_list
    do
        temp_mac="${e%%|*}"
        temp_port="${e##*|}"

        ## outcoming
        last_4_mac=$(echo "$temp_mac" | cut -c9-12)
        first_8_mac=$(echo "$temp_mac" | cut -c1-8)
        #outcoming_mac_filter="match u16 0x$last_4_mac 0xFFFF at -4 match u32 0x$first_8_mac 0xFFFFFFFF at -8 "
        tc filter add dev $WAN_INTF parent 1: protocol ip prio 8 u32 $outcoming_mac_filter\
        match ip sport $temp_port 0xffff \
        flowid 1:3  
        if [ "$enable_ipv6_torrent" = true ] ; then
            tc filter add dev $WAN_INTF parent 1: protocol ipv6 prio 8 u32 $outcoming_mac_filter\
            match ip sport $temp_port 0xffff \
            flowid 1:3
        fi
        ## end outcoming

        ## incoming
        first_4_mac=$(echo "$temp_mac" | cut -c1-4)
        last_8_mac=$(echo "$temp_mac" | cut -c5-12)
        incoming_mac_filter="match u32 0x$last_8_mac 0xFFFFFFFF at -12 match u16 0x$first_4_mac 0xFFFF at -14 "
        tc filter add dev $LAN_INTF parent 1: protocol ip prio 8 u32 $incoming_mac_filter\
        match ip dport $temp_port 0xffff \
        flowid 1:3
        if [ "$enable_ipv6_torrent" = true ] ; then
            tc filter add dev $LAN_INTF parent 1: protocol ipv6 prio 8 u32 $incoming_mac_filter\
            match ip dport $temp_port 0xffff \
            flowid 1:3
        fi
        ## end incoming
    done
fi

if [ "$enable_ip_filter" = true ] ; then
    for e in $ip_port_list
    do
        temp_ip="${e%%|*}"
        temp_port="${e##*|}"

        ## outcoming
        tc filter add dev $WAN_INTF parent 1: protocol ip prio 8 u32 \
        match ip sport $temp_port 0xffff \
        flowid 1:3
        #match ip src $temp_ip \
        ## end outcoming

        ## incoming
        tc filter add dev $LAN_INTF parent 1: protocol ip prio 8 u32 \
        match ip dst $temp_ip \
        match ip dport $temp_port 0xffff \
        flowid 1:3
        ## end incoming
    done
fi