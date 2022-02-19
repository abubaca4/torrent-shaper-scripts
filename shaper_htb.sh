#!/bin/sh

# kernel modules load
modprobe sch_fq_codel
modprobe cls_u32

## settings

# should be with your external ip check it by ifconfig or ip a show
WAN_INTF=eth2.2

# should be local bridge with your switch ports and wifi
LAN_INTF=br0

# download speed
DL_SPEED=150mbit

# upload speed
UL_SPEED=40mbit

# is torrent filtering by mac and port enabled(true)
enable_mac_filter=true

# mac(without :) and port for filter torrents
mac_port_list="629899F3B532|51413 00D86139729B|20000 00241D833036|30000"

# protocol ipv6 filter not work in PADAVAN with kernel 3.4.113 so it option to diasble ipv6 filter(true for enable)
enable_ipv6_torrent=false

# is torrent filtering by ip and port enabled(true)
enable_ip_filter=false

# ip and port for filter torrents
ip_port_list="192.168.8.39|51413 192.168.8.61|20000 192.168.8.44|30000"

## end settings

# remove default
tc qdisc del dev $WAN_INTF root > /dev/null 2>&1
# outcoming traffic
tc qdisc add dev $WAN_INTF root handle 1: htb default 20
tc class add dev $WAN_INTF parent 1: classid 1:1 htb rate $UL_SPEED ceil $UL_SPEED quantum 1500
tc class add dev $WAN_INTF parent 1:1 classid 1:10 htb rate 1Mbit ceil $UL_SPEED prio 2 quantum 1500
tc class add dev $WAN_INTF parent 1:1 classid 1:20 htb rate 2Mbit ceil $UL_SPEED prio 3 quantum 1500
tc class add dev $WAN_INTF parent 1:1 classid 1:30 htb rate 2Mbit ceil $UL_SPEED prio 4 quantum 1500
tc qdisc add dev $WAN_INTF parent 1:10 handle 10: fq_codel limit 10240 quantum 300
tc qdisc add dev $WAN_INTF parent 1:20 handle 20: fq_codel limit 10240 quantum 300
tc qdisc add dev $WAN_INTF parent 1:30 handle 30: pfifo limit 10240

# remove default
tc qdisc del dev $LAN_INTF root > /dev/null 2>&1
# incoming traffic
tc qdisc add dev $LAN_INTF root handle 1: htb default 20
tc class add dev $LAN_INTF parent 1: classid 1:1 htb rate $DL_SPEED ceil $DL_SPEED quantum 1500
tc class add dev $LAN_INTF parent 1:1 classid 1:10 htb rate 10Mbit ceil $DL_SPEED prio 2 quantum 1500
tc class add dev $LAN_INTF parent 1:1 classid 1:20 htb rate 2Mbit ceil $DL_SPEED prio 3 quantum 1500
tc class add dev $LAN_INTF parent 1:1 classid 1:30 htb rate 2Mbit ceil $DL_SPEED prio 4 quantum 1500
tc qdisc add dev $LAN_INTF parent 1:10 handle 10: fq_codel limit 10240 quantum 300
tc qdisc add dev $LAN_INTF parent 1:20 handle 20: fq_codel limit 10240 quantum 300
tc qdisc add dev $LAN_INTF parent 1:30 handle 30: pfifo limit 10240

# trafic filters
###HIGH PRIO
## outcoming
#ICMP
tc filter add dev $WAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 1 0xff flowid 1:10
#ACK
tc filter add dev $WAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 6 0xff match u8 0x05 0x0f at 0 match u16 0x0000 0xffc0 at 2 match u8 0x10 0xff at 33 flowid 1:10
#DNS
tc filter add dev $WAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 17 0xff match ip dport 53 0xffff flowid 1:10
#VOIP
tc filter add dev $WAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0x68 0xff match ip protocol 11 0xff flowid 1:10
tc filter add dev $WAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0xb8 0xff match ip protocol 11 0xff flowid 1:10
#TOS
tc filter add dev $WAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0x10 0xff flowid 1:10
#NTP
tc filter add dev $WAN_INTF parent 1: protocol ip prio 2 u32 match ip protocol 17 0xff match ip dport 123 0xffff flowid 1:10
## incoming
#ICMP
tc filter add dev $LAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 1 0xff flowid 1:10
#ACK
tc filter add dev $LAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 6 0xff match u8 0x05 0x0f at 0 match u16 0x0000 0xffc0 at 2 match u8 0x10 0xff at 33 flowid 1:10
#DNS
tc filter add dev $LAN_INTF parent 1: protocol ip prio 1 u32 match ip protocol 17 0xff match ip sport 53 0xffff flowid 1:10
#VOIP
tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0x68 0xff match ip protocol 11 0xff flowid 1:10
tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0xb8 0xff match ip protocol 11 0xff flowid 1:10
#TOS
tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip tos 0x10 0xff flowid 1:10
#IPTV
#tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip protocol 17 0xff match ip dst 224.0.0.0/3 flowid 1:10
#NTP
tc filter add dev $LAN_INTF parent 1: protocol ip prio 2 u32 match ip protocol 17 0xff match ip sport 123 0xffff flowid 1:10

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
        flowid 1:30
        if [ "$enable_ipv6_torrent" = true ] ; then
            tc filter add dev $WAN_INTF parent 1: protocol ipv6 prio 8 u32 $outcoming_mac_filter\
            match ip sport $temp_port 0xffff \
            flowid 1:30
        fi
        ## end outcoming

        ## incoming
        first_4_mac=$(echo "$temp_mac" | cut -c1-4)
        last_8_mac=$(echo "$temp_mac" | cut -c5-12)
        incoming_mac_filter="match u32 0x$last_8_mac 0xFFFFFFFF at -12 match u16 0x$first_4_mac 0xFFFF at -14 "
        tc filter add dev $LAN_INTF parent 1: protocol ip prio 8 u32 $incoming_mac_filter\
        match ip dport $temp_port 0xffff \
        flowid 1:30
        if [ "$enable_ipv6_torrent" = true ] ; then
            tc filter add dev $LAN_INTF parent 1: protocol ipv6 prio 8 u32 $incoming_mac_filter\
            match ip dport $temp_port 0xffff \
            flowid 1:30
        fi
        ## end incoming
    done
fi

# filter by ip and port for torrents
if [ "$enable_ip_filter" = true ] ; then
    for e in $ip_port_list
    do
        temp_ip="${e%%|*}"
        temp_port="${e##*|}"

        ## outcoming
        #outcoming_ip_filter="match ip src $temp_ip "
        tc filter add dev $WAN_INTF parent 1: protocol ip prio 8 u32 $outcoming_ip_filter\
        match ip sport $temp_port 0xffff \
        flowid 1:30
        ## end outcoming

        ## incoming
        incoming_ip_filter="match ip dst $temp_ip "
        tc filter add dev $LAN_INTF parent 1: protocol ip prio 8 u32 $incoming_ip_filter\
        match ip dport $temp_port 0xffff \
        flowid 1:30
        ## end incoming
    done
fi