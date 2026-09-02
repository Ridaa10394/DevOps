# IP Addressing and Subnetting — Notes

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

---

## What an IP address is

A unique numeric identifier for a device on a network, defined by the **Internet Protocol**. IPv4 is **32 bits**, written as four 8-bit octets in dotted decimal:

```
192.168.1.10
 |   |   | |
 8   8   8 8   bits  =  32 bits total
```

Range: `0.0.0.0` to `255.255.255.255`.

Every IP splits into two parts — a **network portion** and a **host portion**. The subnet mask is what marks the boundary.

---

## Address classes

| Class | First octet | Default mask | CIDR | Purpose |
|---|---|---|---|---|
| A | 1 – 126 | 255.0.0.0 | /8 | Very large networks |
| B | 128 – 191 | 255.255.0.0 | /16 | Medium networks |
| C | 192 – 223 | 255.255.255.0 | /24 | Small networks |
| D | 224 – 239 | — | — | **Multicast** |
| E | 240 – 255 | — | — | **Experimental / reserved** |

Two notes on the edges:

- **127.x.x.x is loopback**, not a usable class A network. That is why class A stops at 126.
- Classes D and E have **no subnet mask** — they are not divided into networks and hosts, so writing `255.255.255.255` as "the class D mask" is incorrect. `255.255.255.255` is the limited-broadcast address.

---

## Subnet masks

The mask marks which bits are network and which are host. A `1` bit is network, a `0` bit is host.

```
255.0.0.0        = 11111111.00000000.00000000.00000000  = /8   (Class A)
255.255.0.0      = 11111111.11111111.00000000.00000000  = /16  (Class B)
255.255.255.0    = 11111111.11111111.11111111.00000000  = /24  (Class C)
255.255.240.0    = 11111111.11111111.11110000.00000000  = /20
```

CIDR notation (`/20`) is just the count of leading `1` bits.

---

## Counting hosts

```
host bits         = 32 - prefix length
total addresses   = 2 ^ host bits
usable addresses  = 2 ^ host bits - 2
```

The `-2` removes two addresses that can never be assigned to a device:

- the **network address** (all host bits `0`)
- the **broadcast address** (all host bits `1`)

| CIDR | Mask | Host bits | Total | Usable |
|---|---|---|---|---|
| /8 | 255.0.0.0 | 24 | 16,777,216 | 16,777,214 |
| /16 | 255.255.0.0 | 16 | 65,536 | 65,534 |
| /20 | 255.255.240.0 | 12 | 4,096 | 4,094 |
| /24 | 255.255.255.0 | 8 | 256 | 254 |
| /25 | 255.255.255.128 | 7 | 128 | 126 |
| /26 | 255.255.255.192 | 6 | 64 | 62 |
| /27 | 255.255.255.224 | 5 | 32 | 30 |
| /28 | 255.255.255.240 | 4 | 16 | 14 |
| /30 | 255.255.255.252 | 2 | 4 | 2 |
| /32 | 255.255.255.255 | 0 | 1 | 1 (single host) |

---

## Worked example 1 — `197.23.45.10 / 255.255.255.0`

```
IP    : 197.23.45.10
Mask  : 255.255.255.0   (/24)
```

First octet is 197, so this is **Class C**.

```
Network bits = 24, host bits = 8

Network address   : 197.23.45.0
First usable host : 197.23.45.1
Last usable host  : 197.23.45.254
Broadcast address : 197.23.45.255

Usable hosts = 2^8 - 2 = 254
```

The network address is found by ANDing the IP with the mask:

```
197.23.45.10   = 11000101.00010111.00101101.00001010
255.255.255.0  = 11111111.11111111.11111111.00000000
AND            = 11000101.00010111.00101101.00000000  = 197.23.45.0
```

---

## Worked example 2 — `120.27.1.0 / 8`

```
IP    : 120.27.1.0
Mask  : 255.0.0.0   (/8)
```

First octet is 120, so this is **Class A**.

```
Network bits = 8, host bits = 24

Network address   : 120.0.0.0
First usable host : 120.0.0.1
Last usable host  : 120.255.255.254
Broadcast address : 120.255.255.255

Usable hosts = 2^24 - 2 = 16,777,214
```

Note that with a /8, only the **first** octet is fixed — `120.27.1.0` and `120.99.250.7` are on the same network.

---

## Worked example 3 — the interface on this machine

```
$ ip addr show eth0
inet 172.21.62.236/20 brd 172.21.63.255
```

```
IP    : 172.21.62.236
Mask  : /20 = 255.255.240.0
```

The interesting octet is the third, because /20 splits it (16 bits + 4 bits):

```
Third octet 62  = 00111110
Mask        240 = 11110000
AND             = 00110000 = 48

Network address   : 172.21.48.0
Broadcast address : 172.21.63.255
Usable range      : 172.21.48.1  -  172.21.63.254
Usable hosts      : 2^12 - 2 = 4094
```

This matches the real output exactly — `ip route` showed the connected route as `172.21.48.0/20`, and `ip addr` reported `brd 172.21.63.255`.

---

## Private IP ranges (RFC 1918)

Not routable on the public internet; reused freely inside private networks and translated by NAT.

| Class | Range | CIDR |
|---|---|---|
| A | 10.0.0.0 – 10.255.255.255 | 10.0.0.0/8 |
| B | 172.16.0.0 – 172.31.255.255 | 172.16.0.0/12 |
| C | 192.168.0.0 – 192.168.255.255 | 192.168.0.0/16 |

The address on this machine, `172.21.62.236`, falls inside `172.16.0.0/12` — a private address, as expected for a virtualised interface.

---

## Special addresses

| Address | Meaning |
|---|---|
| `0.0.0.0` | "This host" / bind to all interfaces |
| `127.0.0.1` | Loopback — this machine |
| `127.0.0.0/8` | The entire loopback range |
| `169.254.0.0/16` | APIPA link-local — assigned when DHCP fails |
| `255.255.255.255` | Limited broadcast |
| `x.x.x.0` (in a /24) | Network address — not assignable |
| `x.x.x.255` (in a /24) | Broadcast address — not assignable |

Seeing a `169.254.x.x` address is a strong signal that **DHCP failed** — the host gave up and self-assigned.

---

## Quick binary reference

| Decimal | Binary | Decimal | Binary |
|---|---|---|---|
| 0 | 00000000 | 240 | 11110000 |
| 128 | 10000000 | 248 | 11111000 |
| 192 | 11000000 | 252 | 11111100 |
| 224 | 11100000 | 254 | 11111110 |
| | | 255 | 11111111 |

Octet bit values: `128 64 32 16 8 4 2 1`.
