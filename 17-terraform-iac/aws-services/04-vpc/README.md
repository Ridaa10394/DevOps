# VPC - Virtual Private Cloud

Name: Ridaa Mirza
Enrollment No: 24BCS10394

## What is a VPC

A VPC is your own private, isolated network inside an AWS region. You choose the IP range, split it into subnets, decide what's reachable from the internet and what isn't. Basically the cloud version of the data-centre network from the networking session.

- One VPC lives in **one region** but spans all its AZs.
- Every account gets a **default VPC** per region (all public subnets) - fine for playing around, not for real work.

## CIDR

CIDR notation (`10.0.0.0/16`) says how big the IP range is - the `/n` is how many bits are fixed.

| CIDR | IPs | Typical use |
|------|-----|-------------|
| /16 | 65,536 | whole VPC (max size) |
| /20 | 4,096 | big subnet |
| /24 | 256 | normal subnet |
| /28 | 16 | smallest allowed |

- Use private ranges (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- AWS reserves **5 IPs per subnet** (network, VPC router, DNS, future use, broadcast) - so a /24 gives 251 usable.
- Don't overlap CIDRs with other VPCs or your office network if you'll ever peer/VPN them.

```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ridaa-vpc}]'
aws ec2 modify-vpc-attribute --vpc-id vpc-0abc --enable-dns-hostnames
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,IsDefault]' --output table
```

## Subnets

A subnet is a slice of the VPC CIDR that lives in **exactly one AZ**. For high availability you make the same tier in at least two AZs.

```bash
aws ec2 create-subnet --vpc-id vpc-0abc --cidr-block 10.0.1.0/24  --availability-zone ap-south-1a   # public-a
aws ec2 create-subnet --vpc-id vpc-0abc --cidr-block 10.0.2.0/24  --availability-zone ap-south-1b   # public-b
aws ec2 create-subnet --vpc-id vpc-0abc --cidr-block 10.0.11.0/24 --availability-zone ap-south-1a   # private-a
aws ec2 create-subnet --vpc-id vpc-0abc --cidr-block 10.0.12.0/24 --availability-zone ap-south-1b   # private-b
aws ec2 modify-subnet-attribute --subnet-id subnet-pubA --map-public-ip-on-launch
```

## Route tables

A route table is a list of "traffic for this destination goes to that target" rules. Each subnet is associated with one route table (the VPC's main one if you don't pick).

Every route table has the `local` route automatically, so everything inside the VPC can talk to each other.

Public route table:

| Destination | Target |
|-------------|--------|
| 10.0.0.0/16 | local |
| 0.0.0.0/0 | igw-xxxx |

Private route table:

| Destination | Target |
|-------------|--------|
| 10.0.0.0/16 | local |
| 0.0.0.0/0 | nat-xxxx |

```bash
aws ec2 create-route-table --vpc-id vpc-0abc
aws ec2 create-route --route-table-id rtb-pub --destination-cidr-block 0.0.0.0/0 --gateway-id igw-0abc
aws ec2 associate-route-table --route-table-id rtb-pub --subnet-id subnet-pubA
aws ec2 describe-route-tables --route-table-ids rtb-pub
```

## Internet Gateway (IGW)

The door between the VPC and the internet. One per VPC, horizontally scaled and highly available by AWS, free. It does two things: lets traffic in/out, and does 1:1 NAT between an instance's private IP and its public IP.

A subnet is "public" only because its route table points `0.0.0.0/0` at the IGW.

```bash
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --internet-gateway-id igw-0abc --vpc-id vpc-0abc
```

## NAT Gateway

Lets instances in **private** subnets make outbound connections (apt/dnf updates, calling external APIs, pulling images) while staying unreachable from the internet.

- Sits in a **public** subnet, needs an Elastic IP.
- Private route table sends `0.0.0.0/0` to it.
- Zonal - for HA put one in each AZ (each private subnet routes to the NAT in its own AZ).
- Costs money per hour + per GB processed - the thing that surprises people on the bill. Delete it after labs.

```bash
aws ec2 allocate-address --domain vpc
aws ec2 create-nat-gateway --subnet-id subnet-pubA --allocation-id eipalloc-0abc
aws ec2 create-route --route-table-id rtb-priv --destination-cidr-block 0.0.0.0/0 --nat-gateway-id nat-0abc
aws ec2 delete-nat-gateway --nat-gateway-id nat-0abc
```

## Security Groups

Stateful firewall attached to an ENI (instance, RDS, load balancer...). Allow rules only. Return traffic automatically allowed. Can reference other SGs as the source - nice for "only the app tier may hit the DB". (More detail in the EC2 notes.)

```bash
aws ec2 authorize-security-group-ingress --group-id sg-db --protocol tcp --port 3306 --source-group sg-app
```

## NACLs - Network Access Control Lists

Stateless firewall at the **subnet** level. Rules are numbered and evaluated lowest first, first match wins, and there are explicit **deny** rules. Because it's stateless you must also allow the return traffic (ephemeral ports 1024-65535).

- Default NACL: allow everything in and out.
- A custom NACL: denies everything until you add rules.
- Good for blocking a specific bad IP range for a whole subnet.

```bash
aws ec2 create-network-acl --vpc-id vpc-0abc
aws ec2 create-network-acl-entry --network-acl-id acl-0abc --ingress --rule-number 100 \
  --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id acl-0abc --ingress --rule-number 90 \
  --protocol -1 --cidr-block 198.51.100.0/24 --rule-action deny
aws ec2 create-network-acl-entry --network-acl-id acl-0abc --egress --rule-number 100 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow
```

### Security Group vs NACL

| | Security Group | NACL |
|-|----------------|------|
| Level | instance / ENI | subnet |
| State | stateful (return traffic auto allowed) | stateless (allow return traffic yourself) |
| Rules | allow only | allow and deny |
| Evaluation | all rules checked together | in number order, first match wins |
| Applies to | only resources you attach it to | everything in the subnet automatically |
| Default | deny all in, allow all out | default NACL allows all |
| Source can be another SG | yes | no, CIDR only |

## Public vs private subnet

| | Public subnet | Private subnet |
|-|---------------|----------------|
| Default route | `0.0.0.0/0 -> IGW` | `0.0.0.0/0 -> NAT GW` (or none) |
| Public IPs | instances can have one | no |
| Reachable from internet | yes (if SG allows) | no |
| What goes here | load balancers, bastion, NAT GW | app servers, databases, caches |

## Diagram - typical 2-tier VPC

```
                               Internet
                                  |
                          +---------------+
                          |  Internet GW  |
                          +-------+-------+
                                  |
+---------------------------------+----------------------------------+
| VPC 10.0.0.0/16  (ap-south-1)   |                                  |
|                                 |                                  |
|  +--------- AZ-a --------------+ +------------- AZ-b ------------+ |
|  | Public subnet 10.0.1.0/24   | |  Public subnet 10.0.2.0/24    | |
|  | rt: 0.0.0.0/0 -> IGW        | |  rt: 0.0.0.0/0 -> IGW         | |
|  |                             | |                               | |
|  |  [ ALB node ]   [ NAT GW ]  | |  [ ALB node ]                 | |
|  |       |             ^       | |        |                      | |
|  +-------|-------------|-------+ +--------|----------------------+ |
|  | Private subnet 10.0.11.0/24 | | Private subnet 10.0.12.0/24   | |
|  | rt: 0.0.0.0/0 -> NAT GW     | | rt: 0.0.0.0/0 -> NAT GW       | |
|  |       v             |       | |        v                      | |
|  |  [ App EC2 ] -------+       | |   [ App EC2 ]                 | |
|  |       |   (outbound only)   | |        |                      | |
|  |       v                     | |        v                      | |
|  |  [ RDS primary ] <==== sync replication ====> [ RDS standby ] | |
|  +-----------------------------+ +-------------------------------+ |
|                                                                    |
|  SG chain: alb-sg (80/443 from 0.0.0.0/0)                          |
|            -> app-sg (8080 from alb-sg)                            |
|            -> db-sg  (3306 from app-sg)                            |
+--------------------------------------------------------------------+
```

Users hit the ALB in the public subnets, the ALB forwards to app servers in the private subnets, app servers talk to the DB, and anything private that needs the internet goes out through the NAT.

## Other bits worth knowing

- **VPC peering** / **Transit Gateway** - connect VPCs together.
- **VPC endpoints** - reach S3/DynamoDB (gateway endpoints, free) or other services (interface endpoints) without going through NAT/internet.
- **VPC Flow Logs** - log accepted/rejected traffic to CloudWatch or S3 for debugging.

```bash
aws ec2 create-vpc-endpoint --vpc-id vpc-0abc --service-name com.amazonaws.ap-south-1.s3 \
  --route-table-ids rtb-priv
aws ec2 create-flow-logs --resource-type VPC --resource-ids vpc-0abc --traffic-type REJECT \
  --log-destination-type s3 --log-destination arn:aws:s3:::ridaa-flow-logs
```
