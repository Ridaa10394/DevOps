# DynamoDB & RDS - Databases on AWS

Name: Ridaa Mirza
Enrollment No: 24BCS10394

AWS has two "default" database answers: DynamoDB for NoSQL key-value, RDS for normal SQL databases. Both are managed - no OS patching, no installing MySQL yourself.

---

## Part A - DynamoDB

### What is DynamoDB

A fully managed, serverless **NoSQL** key-value and document database. No servers or instance sizes to pick - you create a table and start writing. Single-digit millisecond latency at basically any scale, data replicated across 3 AZs automatically.

### NoSQL - what that means here

- No fixed schema - apart from the key, every item can have different attributes.
- No joins. You design the table around your **access patterns** (the queries you'll run), not around normalised entities.
- Scales horizontally by splitting data into partitions based on the partition key.

### Tables, items, attributes

| DynamoDB | Rough SQL equivalent |
|----------|----------------------|
| Table | table |
| Item | row (max 400 KB) |
| Attribute | column (but per item, not fixed) |
| Primary key | primary key |

Example item in a `Orders` table:

```json
{
  "customer_id": "C1001",
  "order_date": "2026-10-07#ORD-552",
  "total": 1499,
  "status": "SHIPPED",
  "items": ["keyboard", "mouse"]
}
```

Attribute types: String, Number, Binary, Boolean, Null, List, Map, String/Number/Binary Set.

### Partition key and sort key

- **Partition key (hash key)** - DynamoDB hashes it to decide which physical partition stores the item. Must be high-cardinality (lots of distinct values) or you get "hot partitions". If it's the only key, it must be unique.
- **Sort key (range key)** - optional. Partition key + sort key together form the unique primary key. Items with the same partition key are stored sorted by sort key, so you can do range queries like "all orders of C1001 in October" (`begins_with(order_date, '2026-10')`).

Extra indexes:

- **GSI (Global Secondary Index)** - a different partition/sort key, query the data another way (e.g. by `status`).
- **LSI (Local Secondary Index)** - same partition key, different sort key, must be made at table creation.

Capacity modes: **On-demand** (pay per request, zero planning) or **Provisioned** (set RCU/WCU, can autoscale, cheaper for steady load).

Other features: TTL (auto-delete expired items), Streams (change feed -> Lambda), PITR backups, Global Tables (multi-region active-active), DAX cache, transactions.

```bash
aws dynamodb create-table --table-name Orders \
  --attribute-definitions AttributeName=customer_id,AttributeType=S AttributeName=order_date,AttributeType=S \
  --key-schema AttributeName=customer_id,KeyType=HASH AttributeName=order_date,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

aws dynamodb wait table-exists --table-name Orders
aws dynamodb describe-table --table-name Orders --query 'Table.[TableStatus,KeySchema]'

aws dynamodb put-item --table-name Orders --item \
  '{"customer_id":{"S":"C1001"},"order_date":{"S":"2026-10-07#ORD-552"},"total":{"N":"1499"},"status":{"S":"SHIPPED"}}'

aws dynamodb get-item --table-name Orders \
  --key '{"customer_id":{"S":"C1001"},"order_date":{"S":"2026-10-07#ORD-552"}}'

# query = uses the key, cheap.  scan = reads the whole table, avoid on big tables
aws dynamodb query --table-name Orders \
  --key-condition-expression "customer_id = :c AND begins_with(order_date, :m)" \
  --expression-attribute-values '{":c":{"S":"C1001"},":m":{"S":"2026-10"}}'

aws dynamodb update-time-to-live --table-name Orders \
  --time-to-live-specification Enabled=true,AttributeName=expires_at
aws dynamodb update-continuous-backups --table-name Orders \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
aws dynamodb delete-table --table-name Orders
```

### DynamoDB use cases

- Session stores, shopping carts, user profiles.
- Gaming leaderboards, IoT/telemetry data.
- Serverless backends (API Gateway + Lambda + DynamoDB).
- Terraform state locking table (older `dynamodb_table` backend setting).
- Anything with predictable key-based lookups at huge scale.

---

## Part B - RDS

### What is RDS

Relational Database Service - managed SQL databases. AWS handles provisioning, OS + engine patching, backups, failover and monitoring. You still pick the instance size, storage and design your schema. You don't get SSH/OS access to the server.

### Supported engines

- MySQL
- PostgreSQL
- MariaDB
- Oracle
- Microsoft SQL Server
- IBM Db2
- **Amazon Aurora** (MySQL- and PostgreSQL-compatible, AWS's own cloud-native engine - storage auto-grows, 6 copies across 3 AZs, up to 15 replicas, Serverless v2 option)

### DB instances

A DB instance is one database server: an instance class (`db.t4g.micro`, `db.m7g.large`, `db.r7g.xlarge`...) + EBS storage (gp3 / io2, storage autoscaling optional) + an endpoint hostname you connect to. It lives in a **DB subnet group** (subnets across at least 2 AZs, normally private).

```bash
aws rds create-db-subnet-group --db-subnet-group-name ridaa-db-subnets \
  --db-subnet-group-description "private subnets" --subnet-ids subnet-privA subnet-privB

aws rds create-db-instance --db-instance-identifier ridaa-mysql \
  --engine mysql --engine-version 8.0 --db-instance-class db.t4g.micro \
  --allocated-storage 20 --storage-type gp3 \
  --master-username admin --manage-master-user-password \
  --db-subnet-group-name ridaa-db-subnets --vpc-security-group-ids sg-db \
  --no-publicly-accessible --storage-encrypted \
  --backup-retention-period 7

aws rds wait db-instance-available --db-instance-identifier ridaa-mysql
aws rds describe-db-instances --db-instance-identifier ridaa-mysql \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address,MultiAZ]'
```

### Security

- Put it in **private subnets**, `--no-publicly-accessible`.
- Security group allows the DB port **only from the app's security group**.
- Encryption at rest with KMS (must be chosen at creation; to encrypt an existing DB, snapshot -> copy encrypted -> restore).
- Encryption in transit with SSL/TLS (`require_secure_transport` / `rds.force_ssl`).
- Master password in **Secrets Manager** (`--manage-master-user-password`) with rotation, instead of hardcoding.
- IAM database authentication (MySQL/Postgres) - log in with a short-lived token instead of a password.
- Audit with CloudTrail (API) and engine logs to CloudWatch.

### Backups

- **Automated backups** - daily snapshot + transaction logs, retention 1-35 days, lets you do **point-in-time restore** to any second in that window.
- **Manual snapshots** - kept until you delete them, can be copied to other regions/accounts.
- Restoring always creates a **new** DB instance (new endpoint).

```bash
aws rds create-db-snapshot --db-instance-identifier ridaa-mysql --db-snapshot-identifier ridaa-before-migration
aws rds restore-db-instance-to-point-in-time --source-db-instance-identifier ridaa-mysql \
  --target-db-instance-identifier ridaa-mysql-restored --restore-time 2026-10-07T10:00:00Z
aws rds describe-db-snapshots --db-instance-identifier ridaa-mysql
```

### Multi-AZ

A **synchronous standby** copy in another AZ. If the primary fails (or during maintenance), RDS flips the DNS endpoint to the standby, usually in 60-120 seconds. App keeps using the same endpoint.

- It's for **high availability**, not for scaling - you can't read from the classic standby.
- (Multi-AZ DB *cluster* deployment for MySQL/Postgres has 2 readable standbys.)

```bash
aws rds modify-db-instance --db-instance-identifier ridaa-mysql --multi-az --apply-immediately
aws rds reboot-db-instance --db-instance-identifier ridaa-mysql --force-failover   # test failover
```

### Read replicas

**Asynchronous** copies used to offload read traffic (reports, analytics, read-heavy APIs).

- Up to 15 per source (MySQL/MariaDB/Postgres), can be cross-region.
- Each has its own endpoint - the app has to send reads there itself.
- Slight replication lag, so reads may be a bit stale.
- Can be promoted to a standalone DB (useful for DR or migrations).

```bash
aws rds create-db-instance-read-replica --db-instance-identifier ridaa-mysql-replica-1 \
  --source-db-instance-identifier ridaa-mysql
aws rds promote-read-replica --db-instance-identifier ridaa-mysql-replica-1
```

| | Multi-AZ | Read replica |
|-|----------|--------------|
| Purpose | availability / failover | read scaling |
| Replication | synchronous | asynchronous |
| Readable | no (classic instance) | yes |
| Endpoint | same as primary | its own |
| Cross-region | no | yes |

### RDS use cases

- Backend database for web apps (users, orders, payments) where you need transactions and joins.
- ERP/CRM and other off-the-shelf apps that expect MySQL/Postgres/Oracle/SQL Server.
- Reporting with read replicas.
- Lift-and-shift of an on-prem SQL database (with DMS).

---

## DynamoDB vs RDS

| | DynamoDB | RDS |
|-|----------|-----|
| Type | NoSQL key-value / document | Relational SQL |
| Schema | flexible, only keys fixed | fixed tables/columns |
| Query language | API (GetItem/Query/Scan), PartiQL | full SQL with joins |
| Joins / complex queries | no - design around access patterns | yes |
| Scaling | automatic, horizontal, near-unlimited | vertical (bigger instance) + read replicas |
| Server management | serverless, nothing to size | pick instance class and storage |
| Availability | 3 AZs by default, Global Tables for multi-region | Multi-AZ optional, cross-region replicas |
| Transactions | yes (limited, up to 100 items) | full ACID |
| Pricing | per request or provisioned RCU/WCU + storage | per instance-hour + storage + I/O |
| Max item/row | 400 KB item | engine dependent |
| Good for | high-scale simple lookups, sessions, IoT, serverless | business data with relations, reporting, existing SQL apps |

Rule of thumb: if I know my exact queries up front and need massive scale with key lookups -> DynamoDB. If the data is relational, I need ad-hoc queries/joins or the app already speaks SQL -> RDS (or Aurora).
