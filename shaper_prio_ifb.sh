#!/bin/sh

# kernel modules load
modprobe sch_fq_codel
modprobe cls_u32
modprobe ifb numifbs=1

# should be with your external ip check it by ifconfig or ip a show
WAN_INTF=eth2.2

WAN_IFB="ifb_${WAN_INTF}"

# remove default
tc qdisc del dev $WAN_INTF root > /dev/null 2>&1
# outcoming traffic
tc qdisc add dev $WAN_INTF root handle 1: prio bands 3 priomap 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
tc qdisc add dev $WAN_INTF parent 1:1 handle 10: fq_codel limit 10240
tc qdisc add dev $WAN_INTF parent 1:2 handle 20: fq_codel limit 10240
tc qdisc add dev $WAN_INTF parent 1:3 handle 30: pfifo limit 10240


# remove default
tc qdisc del dev $WAN_INTF ingress >/dev/null 2>&1
tc qdisc del dev $WAN_IFB root >/dev/null 2>&1
ip link add $WAN_IFB type ifb >/dev/null 2>&1
# incoming traffic
tc qdisc add dev $WAN_IFB root handle 1: prio bands 3 priomap 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
tc qdisc add dev $WAN_IFB parent 1:1 handle 10: fq_codel limit 10240
tc qdisc add dev $WAN_IFB parent 1:2 handle 20: fq_codel limit 10240
tc qdisc add dev $WAN_IFB parent 1:3 handle 30: pfifo limit 10240

ip link set $WAN_IFB up
tc qdisc add dev $WAN_INTF handle ffff: ingress
tc filter add dev $WAN_INTF parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev $WAN_IFB

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
tc filter add dev $WAN_IFB parent 1: protocol ip prio 1 u32 match ip protocol 1 0xff flowid 1:1
#ACK
tc filter add dev $WAN_IFB parent 1: protocol ip prio 1 u32 match ip protocol 6 0xff match u8 0x05 0x0f at 0 match u16 0x0000 0xffc0 at 2 match u8 0x10 0xff at 33 flowid 1:1
#DNS
tc filter add dev $WAN_IFB parent 1: protocol ip prio 1 u32 match ip protocol 17 0xff match ip sport 53 0xffff flowid 1:1
#VOIP
tc filter add dev $WAN_IFB parent 1: protocol ip prio 2 u32 match ip tos 0x68 0xff match ip protocol 11 0xff flowid 1:1
tc filter add dev $WAN_IFB parent 1: protocol ip prio 2 u32 match ip tos 0xb8 0xff match ip protocol 11 0xff flowid 1:1
#TOS
tc filter add dev $WAN_IFB parent 1: protocol ip prio 2 u32 match ip tos 0x10 0xff flowid 1:1
#IPTV
#tc filter add dev $WAN_IFB parent 1: protocol ip prio 2 u32 match ip protocol 17 0xff match ip dst 224.0.0.0/3 flowid 1:1
#NTP
tc filter add dev $WAN_IFB parent 1: protocol ip prio 2 u32 match ip protocol 17 0xff match ip sport 123 0xffff flowid 1:1

###MED PRIO Default
# all other traffic

###LOW PRIO
# for torrents
mac_port_list="629899F3B532|51413 00D86139729B|20000 00241D833036|30000"
enable_ipv6_torrent=false
for e in $mac_port_list
do
    temp_mac="${e%%|*}"
    temp_port="${e##*|}"

    last_4_mac=$(echo "$temp_mac" | cut -c9-12)
    first_8_mac=$(echo "$temp_mac" | cut -c1-8)
    ## outcoming
    tc filter add dev $WAN_INTF parent 1: protocol ip prio 8 u32 \
    match u16 0x$last_4_mac 0xFFFF at -4 \
    match u32 0x$first_8_mac 0xFFFFFFFF at -8 \
    match ip dport $temp_port 0xffff \
    flowid 1:3
    if [ "$enable_ipv6_torrent" = true ] ; then
        tc filter add dev $WAN_INTF parent 1: protocol ipv6 prio 8 u32 \
        match u16 0x$last_4_mac 0xFFFF at -4 \
        match u32 0x$first_8_mac 0xFFFFFFFF at -8 \
        match ip dport $temp_port 0xffff \
        flowid 1:3
    fi

    first_4_mac=$(echo "$temp_mac" | cut -c1-4)
    last_8_mac=$(echo "$temp_mac" | cut -c5-12)
    ## incoming
    tc filter add dev $WAN_IFB parent 1: protocol ip prio 8 u32 \
    match u32 0x$last_8_mac 0xFFFFFFFF at -12 \
    match u16 0x$first_4_mac 0xFFFF at -14 \
    match ip dport $temp_port 0xffff \
    flowid 1:3
    if [ "$enable_ipv6_torrent" = true ] ; then
        tc filter add dev $WAN_IFB parent 1: protocol ipv6 prio 8 u32 \
        match u32 0x$last_8_mac 0xFFFFFFFF at -12 \
        match u16 0x$first_4_mac 0xFFFF at -14 \
        match ip dport $temp_port 0xffff \
        flowid 1:3
    fi
done