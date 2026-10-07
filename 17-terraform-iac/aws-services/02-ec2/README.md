# EC2 - Elastic Compute Cloud

Name: Ridaa Mirza
Enrollment No: 24BCS10394

## What is EC2

EC2 gives you virtual machines ("instances") in the cloud. You pick the OS, CPU/RAM size, disk and network, and you pay per second while it's running. It's the basic IaaS building block - you manage the OS and everything above it, AWS manages the hardware.

## AMI - Amazon Machine Image

An AMI is the template an instance boots from: OS + pre-installed software + root volume snapshot + launch permissions.

- **AWS provided** - Amazon Linux 2023, Ubuntu, Windows Server, etc.
- **Marketplace** - vendor images (e.g. with a firewall or DB already installed).
- **Custom** - you configure an instance and create your own image from it (good for "golden images", or bake with Packer).
- AMIs are **regional** - an AMI ID in `ap-south-1` doesn't exist in `us-east-1` (copy it if needed).

```bash
# latest Amazon Linux 2023 AMI via SSM public parameter
aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text

aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query 'Images[*].[ImageId,Name]' --output table

# make your own AMI from an instance
aws ec2 create-image --instance-id i-0abc123 --name my-web-golden-v1
```

## Instance types

Name format: `t3.micro` = family `t`, generation `3`, size `micro`. Extra letters mean variants: `g` = Graviton (ARM), `a` = AMD, `n` = enhanced networking, `d` = local NVMe.

| Family | Optimised for | Examples | Use |
|--------|---------------|----------|-----|
| General purpose | balanced CPU/RAM | t3, t4g, m6i, m7g | web servers, small apps, dev |
| Compute optimised | CPU | c6i, c7g | batch, gaming servers, encoding |
| Memory optimised | RAM | r6i, x2idn | in-memory DBs, caches, big data |
| Storage optimised | local disk IOPS | i4i, d3 | NoSQL, data warehouses |
| Accelerated | GPU / ML chips | p5, g5, inf2 | ML training/inference, graphics |

`t` types are **burstable** - they earn CPU credits while idle and spend them under load. Fine for low-traffic stuff, bad for constant high CPU. `t2.micro`/`t3.micro` are the free-tier ones.

Pricing models: On-Demand, Reserved Instances / Savings Plans (1-3 year commitment, cheaper), Spot (spare capacity, up to ~90% off, can be taken back with 2 min notice), Dedicated Hosts.

```bash
aws ec2 describe-instance-types --instance-types t3.micro t3.medium \
  --query 'InstanceTypes[*].[InstanceType,VCpuInfo.DefaultVCpus,MemoryInfo.SizeInMiB]' --output table
```

## Key pairs

Used for SSH (Linux) or decrypting the admin password (Windows). AWS keeps the public key and puts it into `~/.ssh/authorized_keys` on boot; you keep the private `.pem`. If you lose the private key, AWS can't give it back.

```bash
aws ec2 create-key-pair --key-name ridaa-key --key-type ed25519 \
  --query 'KeyMaterial' --output text > ridaa-key.pem
chmod 400 ridaa-key.pem

# or import your existing key
aws ec2 import-key-pair --key-name my-laptop --public-key-material fileb://~/.ssh/id_ed25519.pub

ssh -i ridaa-key.pem ec2-user@<public-ip>      # Amazon Linux
ssh -i ridaa-key.pem ubuntu@<public-ip>        # Ubuntu
```

Alternative with no SSH keys or open port 22: **SSM Session Manager** (`aws ssm start-session --target i-0abc123`).

## Security groups

A security group is a **stateful virtual firewall at the instance (ENI) level**.

- Only **allow** rules - no deny rules.
- Stateful: if inbound traffic is allowed, the response goes out automatically.
- Default: all inbound denied, all outbound allowed.
- A source can be a CIDR or **another security group** (e.g. "DB SG allows 3306 only from App SG").

```bash
aws ec2 create-security-group --group-name web-sg --description "web server" --vpc-id vpc-0abc
aws ec2 authorize-security-group-ingress --group-id sg-0abc --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-0abc --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-0abc --protocol tcp --port 22  --cidr 203.0.113.10/32
aws ec2 describe-security-groups --group-ids sg-0abc
```

(Opening 22 to `0.0.0.0/0` is the classic mistake - restrict to your own IP.)

## EBS - Elastic Block Store

EBS is network-attached block storage - basically the instance's hard disk.

- Lives in **one AZ**, attaches to instances in the same AZ.
- Persists independently of the instance (except the root volume, which by default is deleted on terminate - `DeleteOnTermination`).
- Snapshots go to S3 (managed by AWS), are incremental, and can be copied across regions.
- Can be encrypted with KMS.

| Type | What | Use |
|------|------|-----|
| gp3 | general SSD, set IOPS/throughput separately | default for most things |
| io2 | provisioned IOPS SSD | big databases needing steady IOPS |
| st1 | throughput HDD | logs, big sequential reads |
| sc1 | cold HDD | rarely accessed, cheapest |

Instance store is different - physically attached NVMe, very fast, but data is gone when the instance stops.

```bash
aws ec2 create-volume --availability-zone ap-south-1a --size 20 --volume-type gp3 --encrypted
aws ec2 attach-volume --volume-id vol-0abc --instance-id i-0abc --device /dev/sdf
aws ec2 create-snapshot --volume-id vol-0abc --description "before upgrade"
aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=i-0abc
```

## Public vs private IP

| | Private IP | Public IP | Elastic IP |
|-|------------|-----------|------------|
| Reachable from | inside the VPC only | internet | internet |
| Assigned | always, from subnet CIDR | auto, if subnet/launch setting allows | you allocate it |
| On stop/start | stays the same | **changes** | stays the same |
| Cost | free | charged per hour (since 2024) | charged per hour |

The instance itself only knows its private IP - the public IP is NAT'd by the internet gateway. Private-subnet instances have no public IP and reach the internet via a NAT gateway.

```bash
aws ec2 describe-instances --instance-ids i-0abc \
  --query 'Reservations[0].Instances[0].[PrivateIpAddress,PublicIpAddress]'
aws ec2 allocate-address --domain vpc
aws ec2 associate-address --instance-id i-0abc --allocation-id eipalloc-0abc
```

## Instance lifecycle

```
   run-instances                        start
        |                  +-----------------------------------+
        v                  |                                   |
   +---------+        +----v----+   stop    +----------+   +---------+
   | pending |------->| running |---------->| stopping |-->| stopped |
   +---------+        +----+----+           +----------+   +----+----+
                        |  ^  |                                 |
                 reboot |  |  | terminate                       | terminate
                        +--+  |                                 |
                              v                                 |
                     +---------------+                          |
                     | shutting-down |<-------------------------+
                     +-------+-------+
                             |
                             v
                      +------------+
                      | terminated |   gone for good (root EBS deleted by default)
                      +------------+
```

- **Reboot** - same host, keeps private and public IP, RAM is cleared.
- **Stop -> Start** - goes back through `pending`, usually lands on a new host and gets a **new public IP** (private IP and EBS data stay).
- **Stopped** - no compute charge, but EBS storage still billed.
- **Hibernate** - like stop, but RAM is saved to the root EBS volume so it resumes where it left off.
- **Terminated** - can't be brought back. Turn on termination protection for important boxes.

```bash
aws ec2 run-instances --image-id ami-0abc --instance-type t3.micro --key-name ridaa-key \
  --security-group-ids sg-0abc --subnet-id subnet-0abc \
  --user-data file://install-nginx.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-1}]'

aws ec2 describe-instances --filters Name=tag:Name,Values=web-1 \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' --output table
aws ec2 stop-instances      --instance-ids i-0abc
aws ec2 start-instances     --instance-ids i-0abc
aws ec2 reboot-instances    --instance-ids i-0abc
aws ec2 terminate-instances --instance-ids i-0abc
aws ec2 wait instance-running --instance-ids i-0abc
```

User data example (`install-nginx.sh`) - runs once as root at first boot:

```bash
#!/bin/bash
dnf install -y nginx
systemctl enable --now nginx
echo "hello from $(hostname)" > /usr/share/nginx/html/index.html
```

## Common use cases

- Web/app servers, usually behind a load balancer in an Auto Scaling Group.
- Jenkins/GitLab runners and other self-hosted CI agents.
- Bastion host / jump box into private subnets.
- Running Docker or a self-managed Kubernetes cluster (or EKS worker nodes).
- Batch jobs and ML training on Spot / GPU instances.
- Lift-and-shift of on-prem VMs.
