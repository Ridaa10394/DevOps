# Session 4 - Networking Fundamentals

Name: Ridaa Mirza
Enrollment No: 24BCS10394

Ran everything on Ubuntu 24.04.1 LTS. Full raw output: [commands-output.txt](commands-output.txt).
Subnetting and IP class notes: [subnetting-notes.md](subnetting-notes.md).

## Task 1 - Trying out the commands from the devops-hero repo

### hostname / hostname -I

```
$ hostname
RidasDen

$ hostname -I
172.21.62.236
```

hostname just gives the machine's name, and -I lists all the IPs it has without any extra text around them. Useful if you need a box's IP inside a script since there is nothing to parse out.

### ip addr show

```
$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:15:5d:48:96:06 brd ff:ff:ff:ff:ff:ff
    inet 172.21.62.236/20 brd 172.21.63.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::215:5dff:fe48:9606/64 scope link
```

This is the modern replacement for ifconfig. Going through it interface by interface:

- lo is the loopback, always 127.0.0.1/8, never leaves the machine
- eth0 is the real network card, and it is UP and LOWER_UP so the link is actually live
- inet 172.21.62.236/20 is the IPv4 address, /20 prefix, which works out to a netmask of 255.255.240.0, 12 host bits, so 4094 usable addresses
- brd 172.21.63.255 is the broadcast address for that subnet
- link/ether 00:15:5d:48:96:06 is the MAC address
- mtu 1500 is the standard ethernet frame size
- fe80::/64 is the link-local IPv6 address, generated from the MAC

`ip -brief addr show` gives basically the same info but squeezed to one line per interface, easier to scan quickly:

```
$ ip -brief addr show
lo               UNKNOWN        127.0.0.1/8 10.255.255.254/32 ::1/128
eth0             UP             172.21.62.236/20 fe80::215:5dff:fe48:9606/64
```

### ip route show

```
$ ip route show
default via 172.21.48.1 dev eth0 proto kernel
172.21.48.0/20 dev eth0 proto kernel scope link src 172.21.62.236
```

This is the kernel's routing table, decides where every packet actually goes.

- line 2 is the directly connected route, anything in 172.21.48.0/20 is on the local link and does not need a router
- line 1 is the default route (0.0.0.0/0), everything else goes to the gateway 172.21.48.1. This is the line to check first when you have an IP but no internet - if the default route is missing, only local stuff works.

### ping

```
$ ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=115 time=15.6 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=115 time=43.7 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=115 time=127 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=115 time=18.2 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 15.567/51.038/126.705/45.050 ms
```

```
$ ping -c 4 google.com
PING google.com (142.251.221.238) 56(84) bytes of data.
64 bytes from pnbomb-bk-in-f14.1e100.net (142.251.221.238): icmp_seq=1 ttl=116 time=42.8 ms
...
4 packets transmitted, 4 received, 0% packet loss, time 3270ms
rtt min/avg/max/mdev = 23.917/33.101/42.807/6.768 ms
```

ping sends ICMP echo requests and times how long the replies take.

- icmp_seq goes up per packet, gaps in the sequence mean dropped packets
- ttl=115 is however much time-to-live is left. It starts at 128 on the responder, so around 13 hops away
- time is the round trip time. Here it ranged from 15ms to 127ms which shows there is real jitter on this connection
- 0% packet loss is the main thing you want to see

One trick worth remembering: pinging an IP like 8.8.8.8 checks raw connectivity, while pinging google.com also checks DNS. If the IP works but the name does not resolve, the problem is DNS, not the network itself.

### ss -tuln (listening sockets)

```
$ ss -tuln
Netid State  Recv-Q Send-Q  Local Address:Port  Peer Address:Port
udp   UNCONN 0      0          127.0.0.54:53         0.0.0.0:*
udp   UNCONN 0      0       127.0.0.53%lo:53         0.0.0.0:*
udp   UNCONN 0      0           127.0.0.1:323        0.0.0.0:*
tcp   LISTEN 0      4096    127.0.0.53%lo:53         0.0.0.0:*
tcp   LISTEN 0      200         127.0.0.1:5432       0.0.0.0:*
tcp   LISTEN 0      1000   10.255.255.254:53         0.0.0.0:*
```

ss is the newer, faster version of netstat. The flags break down as -t TCP, -u UDP, -l listening only, -n numeric ports so it does not try to look up names.

Reading this: port 53 is DNS (systemd-resolved), 5432 is PostgreSQL, 323 is chronyd (NTP). What matters is the bind address - 127.0.0.1:5432 means PostgreSQL only takes local connections, while 0.0.0.0:port would accept connections from anywhere. That is the first thing to check if a remote client cannot connect to something.

### netstat -rn and route -n

```
$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         172.21.48.1     0.0.0.0         UG        0 0          0 eth0
172.21.48.0     0.0.0.0         255.255.240.0   U         0 0          0 eth0
```

Same routing table as ip route, just the older format. The Flags column is the useful bit here - U means the route is up, G means it goes through a gateway. So row 1 is the default route out and row 2 is the local subnet. Genmask 255.255.240.0 is just the /20 from earlier written out in dotted decimal.

### arp -a

```
$ arp -a
RidasDen.mshome.net (172.21.48.1) at 00:15:5d:75:35:d5 [ether] on eth0
```

ARP maps IP addresses to MAC addresses. Before sending a frame to a local IP, the host needs to know the MAC address, so it broadcasts "who has 172.21.48.1?" and caches whatever answers. This table is that cache. Only the gateway shows up here because it is the only local machine talked to so far.

### cat /etc/resolv.conf (DNS config)

```
$ cat /etc/resolv.conf
# This file was automatically generated by WSL.
nameserver 10.255.255.254
```

This lists which DNS servers the system asks. If names stop resolving while raw IPs still ping fine, this is the first file to check.

### curl (HTTP client)

```
$ curl -s -o /dev/null -w '...' https://www.google.com
HTTP status : 200
Resolved IP : 142.251.155.119
DNS time    : 0.049302s
Connect time: 0.060684s
Total time  : 0.274625s
```

```
$ curl -sI https://api.github.com | head -8
HTTP/2 200
date: Wed, 02 Sep 2026 17:21:42 GMT
cache-control: public, max-age=60, s-maxage=60
vary: Accept,Accept-Encoding, Accept, X-Requested-With
x-github-api-version-selected: 2022-11-28
access-control-allow-origin: *
strict-transport-security: max-age=31536000; includeSubdomains; preload
```

curl tests the application layer, not just whether something is reachable. -I fetches headers only. The -w timing breakdown is genuinely handy for debugging since it splits out DNS time (0.049s) from connect time (0.060s) from total time (0.274s), so you can tell if slowness is DNS, the TCP/TLS handshake, or the server itself. Also note HTTP/2 on the GitHub response.

### nc -zv (port connectivity test)

```
$ nc -zv google.com 443
Connection to google.com (142.251.221.238) 443 port [tcp/https] succeeded!
```

netcat with -z (just scan, no data sent) and -v (verbose) checks whether one specific TCP port is open. This is better than ping for checking a service, because ping uses ICMP which proves nothing about whether port 443 is actually open - lots of hosts block ICMP while still serving traffic fine.

### ifconfig eth0

```
$ ifconfig eth0
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.21.62.236  netmask 255.255.240.0  broadcast 172.21.63.255
        inet6 fe80::215:5dff:fe48:9e99  prefixlen 64  scopeid 0x20<link>
        ether 00:15:5d:48:9e:99  txqueuelen 1000  (Ethernet)
        RX packets 24  bytes 15345 (15.3 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 40  bytes 5106 (5.1 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

The old tool from net-tools, deprecated in favour of ip. Shows the netmask in dotted decimal instead of CIDR, which is arguably easier to read. One thing ip addr does not give you that this does: the RX/TX counters, packet and error counts per interface. Non-zero errors, dropped or collisions point at a physical or driver level problem.

### ss -s (socket summary)

```
$ ss -s
Total: 192
TCP:   7 (estab 1, closed 1, orphaned 1, timewait 1)

Transport Total     IP        IPv6
RAW       0         0         0
UDP       6         5         1
TCP       6         6         0
INET      12        11        1
```

Just a count of sockets by state. A large timewait count is normal if there are lots of short-lived connections, but a large orphaned count usually means an app is leaking sockets somewhere.

## Task 2 - Command reference table

| Command | Layer | What it answers |
|---|---|---|
| `ip addr` / `ifconfig` | 2-3 | What IP and MAC do my interfaces have? |
| `ip route` / `route -n` | 3 | Where do my packets go? |
| `ping` | 3 (ICMP) | Is the host reachable, and how fast? |
| `arp -a` | 2-3 | Which MAC belongs to which local IP? |
| `ss -tuln` / `netstat -tuln` | 4 | What ports am I listening on? |
| `nc -zv host port` | 4 | Is that specific port open? |
| `cat /etc/resolv.conf` | 7 | Which DNS servers do I use? |
| `dig` / `nslookup` | 7 | What does this name resolve to? |
| `curl -I` | 7 | Is the HTTP service actually responding? |
| `traceroute` | 3 | Which routers are in the path? |

dig, nslookup, traceroute, tcpdump and nmap are not installed in this environment, and installing them needs root:

```bash
sudo apt install -y dnsutils traceroute tcpdump nmap
```

Used getent hosts and ping resolving google.com to 142.251.221.238 instead to show DNS working.

## A troubleshooting order that follows the layers

Going bottom up isolates a fault in about 5 or 6 commands:

1. `ip link show` - is the interface UP? (layer 1-2)
2. `ip addr show` - do I have an IP address? (layer 3)
3. `ping <gateway>` - can I reach my own router? (local subnet)
4. `ping 8.8.8.8` - can I reach the internet by IP? (routing / NAT)
5. `ping google.com` - does DNS work? (if 4 passes and 5 fails, it is DNS)
6. `nc -zv host port` - is the specific service reachable? (layer 4)
7. `curl -I` - is the application actually responding correctly? (layer 7)

Whichever step fails first tells you which layer to go dig into.
