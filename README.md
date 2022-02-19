# Torrents shaper scripts
## General idea
I found some shaping scripts with main idea- max priority for service traffic, medium priority for browsing and low for for everything else. But i think it's not a good idea because it's hard to filter game traffic to mark it as a medium priority. My idea is to set default priority medium and filter fat traffic like torrents to low priority manually. Usually you know source of fat traffic in your net.
## Notes
I note that when qos enabled wifi<->lan connections cause cpu load.

I made it for PADAVAN router firmware. I think it also can work with openwrt and any other linux with necessary kernel modules.
## Incoming traffic filtering features
There is two modes of of filtering incoming traffic.
### non-ifb
Shaper work on local bridge with lan and wifi. You can filter traffic by mac or ip of destination. It's one problem incoming traffic of router not catching by qos.
### ifb
Shaper create ifb interface and mirror all incoming traffic to it. You can't filter traffic by mac or ip of destination. It can take more cpu resources than non-ifb mode.
## Outcoming traffic filtering features
You can't filter traffic by mac or ip of source.(the reason is the nat translation)
## prio or htb
### prio
It simpler than htb and not limiting bandwidth. You can try it if you have fttx or fttb internet connection.
### htb
It limiting bandwidth DL_SPEED and UL_SPEED settings. Highly recommended to use it when internet connection is docsis or any dsl(like adsl). In my case it give 10-15% less speed than prio but much more stable delays. You should set speed limit in 95% of your max speed.
## settings 
```
WAN_INTF=eth2.2
```
Your wan interface. You can find it in ```ip a show``` or ```ifconfig```. Usually it has your external ip.
```
LAN_INTF=br0
```
Should be local bridge with your lan and wifi. For non ifb only.
```
enable_mac_filter=true
```
Is filter by mac and port enabled.
```
mac_port_list="629899F3B532|51413 00D86139729B|20000 00241D833036|30000"
```
List of mac(without :) and port separated by space.
```
enable_ipv6_torrent=false
```
I tried to filter by mac ipv6 traffic also but ```protocol ipv6``` not work on padavan so I disabled it.
```
enable_ip_filter=false
```
Is filter by ip and port enabled.
```
ip_port_list="192.168.8.39|51413 192.168.8.61|20000 192.168.8.44|30000"
```
The same format as in mac_port_list.
```
DL_SPEED=150mbit
```
Download speed. May not be an integer.
```
UL_SPEED=40mbit
```
Upload speed.