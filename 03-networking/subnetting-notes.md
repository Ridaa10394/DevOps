# IP Addressing and Subnetting - Notes

Name: Ridaa Mirza
Enrollment No: 24BCS10394

## What an IP address is

A number that uniquely identifies a device on a network, defined by the Internet Protocol. IPv4 is 32 bits, written as four 8-bit octets separated by dots:

```
192.168.1.10
 |   |   | |
 8   8   8 8   bits  =  32 bits total
```

Range: 0.0.0.0 to 255.255.255.255.

Every IP is really split into two parts, a network part and a host part. The subnet mask is what tells you where that split happens.

## Address classes

| Class | First octet | Default mask | CIDR | Purpose |
|---|---|---|---|---|
| A | 1 - 126 | 255.0.0.0 | /8 | very large networks |
| B | 128 - 191 | 255.255.0.0 | /16 | medium networks |
| C | 192 - 223 | 255.255.255.0 | /24 | small networks |
| D | 224 - 239 | - | - | multicast |
| E | 240 - 255 | - | - | experimental / reserved |

Two things worth noting:

- 127.x.x.x is loopback, not really a usable class A network, that is why class A stops at 126 instead of 127.
- Classes D and E do not have a subnet mask, they are not split into network/host, so 255.255.255.255 is not "the class D mask" - it is the limited broadcast address.

## Subnet masks

A 1 bit in the mask means network, a 0 bit means host.

```
255.0.0.0        = 11111111.00000000.00000000.00000000  = /8   (Class A)
255.255.0.0      = 11111111.11111111.00000000.00000000  = /16  (Class B)
255.255.255.0    = 11111111.11111111.11111111.00000000  = /24  (Class C)
255.255.240.0    = 11111111.11111111.11110000.00000000  = /20
```

CIDR notation (/20) is just counting the leading 1 bits.

## Counting hosts

```
host bits         = 32 - prefix length
total addresses   = 2 ^ host bits
usable addresses  = 2 ^ host bits - 2
```

The -2 is because two addresses in every subnet can never actually be given to a device:

- the network address (all host bits 0)
- the broadcast address (all host bits 1)

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

## Worked example 1 - 197.23.45.10 / 255.255.255.0

```
IP    : 197.23.45.10
Mask  : 255.255.255.0   (/24)
```

First octet is 197, so this is class C.

```
Network bits = 24, host bits = 8

Network address   : 197.23.45.0
First usable host : 197.23.45.1
Last usable host  : 197.23.45.254
Broadcast address : 197.23.45.255

Usable hosts = 2^8 - 2 = 254
```

Find the network address by ANDing the IP with the mask:

```
197.23.45.10   = 11000101.00010111.00101101.00001010
255.255.255.0  = 11111111.11111111.11111111.00000000
AND            = 11000101.00010111.00101101.00000000  = 197.23.45.0
```

## Worked example 2 - 120.27.1.0 / 8

```
IP    : 120.27.1.0
Mask  : 255.0.0.0   (/8)
```

First octet is 120, so this is class A.

```
Network bits = 8, host bits = 24

Network address   : 120.0.0.0
First usable host : 120.0.0.1
Last usable host  : 120.255.255.254
Broadcast address : 120.255.255.255

Usable hosts = 2^24 - 2 = 16,777,214
```

With a /8, only the first octet is fixed, so 120.27.1.0 and 120.99.250.7 are actually on the same network.

## Worked example 3 - the interface on this machine

```
$ ip addr show eth0
inet 172.21.62.236/20 brd 172.21.63.255
```

```
IP    : 172.21.62.236
Mask  : /20 = 255.255.240.0
```

The interesting octet here is the third one, since /20 splits it into 16 bits + 4 bits:

```
Third octet 62  = 00111110
Mask        240 = 11110000
AND             = 00110000 = 48

Network address   : 172.21.48.0
Broadcast address : 172.21.63.255
Usable range      : 172.21.48.1  -  172.21.63.254
Usable hosts      : 2^12 - 2 = 4094
```

This matches the real output from earlier - ip route showed the connected route as 172.21.48.0/20, and ip addr reported brd 172.21.63.255.

## Private IP ranges (RFC 1918)

Not routable on the public internet, reused freely inside private networks and translated by NAT.

| Class | Range | CIDR |
|---|---|---|
| A | 10.0.0.0 - 10.255.255.255 | 10.0.0.0/8 |
| B | 172.16.0.0 - 172.31.255.255 | 172.16.0.0/12 |
| C | 192.168.0.0 - 192.168.255.255 | 192.168.0.0/16 |

The address on this machine, 172.21.62.236, falls inside 172.16.0.0/12, so it is a private address, which makes sense for a virtualised interface.

## Special addresses

| Address | Meaning |
|---|---|
| `0.0.0.0` | "this host" / bind to all interfaces |
| `127.0.0.1` | loopback, this machine |
| `127.0.0.0/8` | the whole loopback range |
| `169.254.0.0/16` | APIPA link-local, assigned when DHCP fails |
| `255.255.255.255` | limited broadcast |
| `x.x.x.0` (in a /24) | network address, not assignable |
| `x.x.x.255` (in a /24) | broadcast address, not assignable |

Seeing a 169.254.x.x address usually means DHCP failed and the host just self-assigned one.

## Quick binary reference

| Decimal | Binary | Decimal | Binary |
|---|---|---|---|
| 0 | 00000000 | 240 | 11110000 |
| 128 | 10000000 | 248 | 11111000 |
| 192 | 11000000 | 252 | 11111100 |
| 224 | 11100000 | 254 | 11111110 |
| | | 255 | 11111111 |

Octet bit values: 128 64 32 16 8 4 2 1.
