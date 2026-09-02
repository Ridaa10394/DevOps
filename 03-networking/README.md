# Session 4 — Networking Fundamentals

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

Every command below was executed on **Ubuntu 24.04.1 LTS**. Full raw output: [`commands-output.txt`](commands-output.txt).
Subnetting and IP-class notes: [`subnetting-notes.md`](subnetting-notes.md).

---

## Task 1 — Practice the commands from the devops-hero repo

### `hostname` / `hostname -I`

```
$ hostname
RidasDen

$ hostname -I
172.21.62.236
```

**What I understood:** `hostname` returns the machine's name; `-I` lists all configured IP addresses without any of the surrounding text. `-I` is the quick way to grab a box's IP inside a script, since it needs no parsing.

---

### `ip addr show`

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

**What I understood:** this is the modern replacement for `ifconfig`. Reading it interface by interface:

- `lo` is the loopback — always `127.0.0.1/8`, never leaves the machine.
- `eth0` is the real NIC. It is `UP` and `LOWER_UP` (link layer is live).
- `inet 172.21.62.236/20` — the IPv4 address with a **/20** prefix, so the netmask is `255.255.240.0`. That gives 12 host bits → 4094 usable addresses.
- `brd 172.21.63.255` is the broadcast address for that subnet.
- `link/ether 00:15:5d:48:96:06` is the MAC address (layer 2).
- `mtu 1500` is the standard Ethernet maximum frame payload.
- `fe80::/64` is the link-local IPv6 address, auto-generated from the MAC.

`ip -brief addr show` gives the same information condensed to one line per interface, which is far easier to scan:

```
$ ip -brief addr show
lo               UNKNOWN        127.0.0.1/8 10.255.255.254/32 ::1/128
eth0             UP             172.21.62.236/20 fe80::215:5dff:fe48:9606/64
```

---

### `ip route show`

```
$ ip route show
default via 172.21.48.1 dev eth0 proto kernel
172.21.48.0/20 dev eth0 proto kernel scope link src 172.21.62.236
```

**What I understood:** the kernel's routing table, which decides where each packet is sent.

- Line 2 is the **directly connected** route: anything in `172.21.48.0/20` is on the local link, reachable without a router.
- Line 1 is the **default route** (`0.0.0.0/0`): everything else goes to the gateway `172.21.48.1`. This is the single most important line when debugging "I have an IP but no internet" — if the default route is missing, only local traffic works.

---

### `ping`

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

**What I understood:** `ping` sends ICMP echo requests and times the replies.

- `icmp_seq` increments per packet — gaps in the sequence mean dropped packets.
- `ttl=115` is the remaining Time To Live. It starts at 128 on the responder, so roughly 13 routers sat between us.
- `time=` is the round-trip time. The spread here (15 ms to 127 ms) shows real jitter on this link.
- **0% packet loss** is the headline number.

The diagnostic trick: pinging `8.8.8.8` (an IP) tests raw connectivity, while pinging `google.com` additionally tests **DNS**. If the IP works but the name does not, the fault is DNS, not the network.

---

### `ss -tuln` — listening sockets

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

**What I understood:** `ss` is the modern, faster replacement for `netstat`. The flags decompose as `-t` TCP, `-u` UDP, `-l` listening only, `-n` numeric ports (no name lookup).

Reading the output: port **53** is DNS (`systemd-resolved`), port **5432** is PostgreSQL, port **323** is `chronyd` (NTP). The **bind address matters**: `127.0.0.1:5432` means PostgreSQL only accepts local connections, whereas `0.0.0.0:port` would accept connections from anywhere. That distinction is the first thing to check when a remote client cannot connect.

---

### `netstat -rn` and `route -n`

```
$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         172.21.48.1     0.0.0.0         UG        0 0          0 eth0
172.21.48.0     0.0.0.0         255.255.240.0   U         0 0          0 eth0
```

**What I understood:** the same routing table as `ip route`, in the older format. The `Flags` column is the useful part: `U` means the route is Up, and `G` means it goes via a Gateway. So the first row is the default route out, and the second is the local subnet. `Genmask 255.255.240.0` is the dotted-decimal form of the `/20` seen earlier.

---

### `arp -a`

```
$ arp -a
RidasDen.mshome.net (172.21.48.1) at 00:15:5d:75:35:d5 [ether] on eth0
```

**What I understood:** ARP (Address Resolution Protocol) maps **layer 3 IP addresses to layer 2 MAC addresses**. Before sending a frame to a local IP, the host must know the destination MAC; it broadcasts "who has 172.21.48.1?" and caches the reply. This table is that cache. Only the gateway appears here because it is the only local machine we have talked to.

---

### `cat /etc/resolv.conf` — DNS configuration

```
$ cat /etc/resolv.conf
# This file was automatically generated by WSL.
nameserver 10.255.255.254
```

**What I understood:** this file lists the DNS resolvers the system will query. If name resolution fails while raw IPs still ping, this file is the first place to look.

---

### `curl` — HTTP client

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

**What I understood:** `curl` tests the application layer, not just reachability. `-I` fetches headers only. The `-w` timing breakdown is genuinely useful for diagnosis: it separates **DNS time** (0.049 s) from **connect time** (0.060 s) from **total time** (0.274 s), so you can tell whether slowness is DNS, the TCP/TLS handshake, or the server itself. Note `HTTP/2` on the GitHub response.

---

### `nc -zv` — port connectivity test

```
$ nc -zv google.com 443
Connection to google.com (142.251.221.238) 443 port [tcp/https] succeeded!
```

**What I understood:** netcat with `-z` (scan, send no data) and `-v` (verbose) checks whether a **specific TCP port** is reachable. This is strictly better than `ping` for debugging a service, because `ping` uses ICMP and proves nothing about whether port 443 is actually open — many hosts block ICMP while serving traffic perfectly.

---

### `ifconfig eth0`

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

**What I understood:** the legacy tool (from `net-tools`), deprecated in favour of `ip`. It shows the netmask in dotted-decimal rather than CIDR, which is easier to read. The part `ip addr` does *not* give you is the **RX/TX counters** — packet and error counts per interface. Non-zero `errors`, `dropped`, or `collisions` point at a physical or driver-level fault.

---

### `ss -s` — socket summary

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

**What I understood:** an aggregate count of sockets by state. A large `timewait` count is a normal artefact of many short-lived connections; a large `orphaned` count suggests an application leaking sockets.

---

## Task 2 — Command reference table

| Command | Layer | What it answers |
|---|---|---|
| `ip addr` / `ifconfig` | 2–3 | What IP and MAC do my interfaces have? |
| `ip route` / `route -n` | 3 | Where do my packets go? |
| `ping` | 3 (ICMP) | Is the host reachable, and how fast? |
| `arp -a` | 2–3 | Which MAC belongs to which local IP? |
| `ss -tuln` / `netstat -tuln` | 4 | What ports am I listening on? |
| `nc -zv host port` | 4 | Is that specific port open? |
| `cat /etc/resolv.conf` | 7 | Which DNS servers do I use? |
| `dig` / `nslookup` | 7 | What does this name resolve to? |
| `curl -I` | 7 | Is the HTTP service actually responding? |
| `traceroute` | 3 | Which routers are in the path? |

### Commands not run here

`dig`, `nslookup`, `traceroute`, `tcpdump`, and `nmap` are not installed in this environment and installing them needs `root`:

```bash
sudo apt install -y dnsutils traceroute tcpdump nmap
```

DNS resolution was demonstrated instead with `getent hosts` and with `ping` resolving `google.com` to `142.251.221.238`.

---

## A troubleshooting order that follows the layers

Working bottom-up isolates a fault in about five commands:

1. `ip link show` — is the interface **UP**? (layer 1–2)
2. `ip addr show` — do I have an **IP address**? (layer 3)
3. `ping <gateway>` — can I reach my **own router**? (local subnet)
4. `ping 8.8.8.8` — can I reach the **internet by IP**? (routing / NAT)
5. `ping google.com` — does **DNS** work? (if 4 passes and 5 fails, it is DNS)
6. `nc -zv host port` — is the **specific service** reachable? (layer 4)
7. `curl -I` — is the **application** responding correctly? (layer 7)

The first step that fails tells you which layer to investigate.
