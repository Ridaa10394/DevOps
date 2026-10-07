# S3 - Simple Storage Service

Name: Ridaa Mirza
Enrollment No: 24BCS10394

## What is S3

S3 is AWS's object storage. You throw files ("objects") into containers ("buckets") and get them back over HTTPS/API. No disks to manage, practically unlimited space, designed for 11 nines (99.999999999%) durability - data is copied across at least 3 AZs for most classes.

It's **not** a filesystem - no real folders, no editing part of a file in place, no mounting it like a disk (well, not natively). It's key -> blob.

## Buckets

- Bucket names are **globally unique** across every AWS account (that's why the Terraform demo adds a random suffix).
- 3-63 chars, lowercase, numbers, hyphens.
- A bucket is created in one region; data stays there unless you replicate it.
- New buckets are private by default, with Block Public Access on and SSE-S3 encryption on.

```bash
aws s3 mb s3://ridaa-notes-2026 --region ap-south-1
aws s3 ls
aws s3api get-bucket-location --bucket ridaa-notes-2026
aws s3 rb s3://ridaa-notes-2026 --force     # deletes all objects then the bucket
```

## Objects

An object = **key** (full name, e.g. `logs/2026/10/app.log`) + **data** (up to 5 TB) + **metadata** + optional version ID and tags.

The "folders" in the console are just key prefixes with `/`. Uploads over 100 MB should use multipart upload (the CLI does this automatically).

```bash
aws s3 cp notes.txt s3://ridaa-notes-2026/docs/notes.txt
aws s3 ls s3://ridaa-notes-2026 --recursive --human-readable
aws s3 sync ./site s3://ridaa-notes-2026/site --delete
aws s3 cp s3://ridaa-notes-2026/docs/notes.txt ./downloaded.txt
aws s3 rm s3://ridaa-notes-2026/docs/notes.txt

# temporary download link (1 hour) without making anything public
aws s3 presign s3://ridaa-notes-2026/docs/notes.txt --expires-in 3600

aws s3api head-object --bucket ridaa-notes-2026 --key docs/notes.txt
```

## Storage classes

| Class | Access pattern | Min storage duration | Retrieval | Notes |
|-------|----------------|----------------------|-----------|-------|
| S3 Standard | frequent | none | instant | default, 3+ AZs |
| S3 Intelligent-Tiering | unknown/changing | none | instant (archive tiers optional) | auto-moves objects between tiers, small monitoring fee |
| S3 Standard-IA | infrequent | 30 days | instant, per-GB retrieval fee | backups you still need fast |
| S3 One Zone-IA | infrequent, re-creatable | 30 days | instant | single AZ, cheaper, lost if AZ dies |
| S3 Express One Zone | very frequent, low latency | none | single-digit ms | directory buckets, one AZ |
| Glacier Instant Retrieval | ~once a quarter | 90 days | milliseconds | archives that occasionally need instant access |
| Glacier Flexible Retrieval | ~once a year | 90 days | minutes to 12 hours | classic archive |
| Glacier Deep Archive | rarely/never | 180 days | 12-48 hours | cheapest, compliance data |

```bash
aws s3 cp bigbackup.tar s3://ridaa-notes-2026/backups/ --storage-class STANDARD_IA
```

## Versioning

With versioning on, every overwrite creates a new version and a delete just adds a **delete marker** - old versions are still there and can be restored. Protects against "oops, I deleted it".

- States: Unversioned (default) -> Enabled -> Suspended. Once enabled you can never go back to unversioned, only suspend.
- Every version is billed, so pair it with a lifecycle rule to clean up old versions.
- MFA Delete can be added so deleting versions needs MFA.
- Required for replication (CRR/SRR).

```bash
aws s3api put-bucket-versioning --bucket ridaa-notes-2026 --versioning-configuration Status=Enabled
aws s3api get-bucket-versioning --bucket ridaa-notes-2026
aws s3api list-object-versions --bucket ridaa-notes-2026 --prefix docs/notes.txt
aws s3api get-object --bucket ridaa-notes-2026 --key docs/notes.txt --version-id <id> old.txt
```

## Lifecycle policies

Rules that automatically move objects to cheaper classes or delete them after N days. Can be filtered by prefix or tag.

Sample `lifecycle.json`:

```json
{
  "Rules": [
    {
      "ID": "logs-tiering-and-expiry",
      "Status": "Enabled",
      "Filter": { "Prefix": "logs/" },
      "Transitions": [
        { "Days": 30,  "StorageClass": "STANDARD_IA" },
        { "Days": 90,  "StorageClass": "GLACIER" },
        { "Days": 180, "StorageClass": "DEEP_ARCHIVE" }
      ],
      "Expiration": { "Days": 365 }
    },
    {
      "ID": "cleanup-old-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": { "NoncurrentDays": 30 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    }
  ]
}
```

```bash
aws s3api put-bucket-lifecycle-configuration --bucket ridaa-notes-2026 \
  --lifecycle-configuration file://lifecycle.json
aws s3api get-bucket-lifecycle-configuration --bucket ridaa-notes-2026
```

## Encryption

**At rest:**

| Option | Who manages the key | Notes |
|--------|---------------------|-------|
| SSE-S3 (AES256) | S3 | default on all new buckets, nothing to set up (used in my Terraform demo) |
| SSE-KMS | KMS key (AWS-managed or your CMK) | audit trail in CloudTrail, key policies, can enable Bucket Key to cut KMS cost |
| DSSE-KMS | KMS, two layers | for compliance that needs dual-layer |
| SSE-C | you send the key with every request | AWS never stores it |
| Client-side | you encrypt before upload | S3 only sees ciphertext |

**In transit:** HTTPS. You can force it with a bucket policy denying `aws:SecureTransport = false`.

```bash
aws s3api put-bucket-encryption --bucket ridaa-notes-2026 --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms","KMSMasterKeyID":"alias/my-key"},"BucketKeyEnabled":true}]}'
aws s3api get-bucket-encryption --bucket ridaa-notes-2026
```

## Bucket policies

A bucket policy is a resource-based IAM policy attached to the bucket. It has a `Principal` (who), unlike identity policies. Used for cross-account access, forcing HTTPS/encryption, allowing CloudFront, or (carefully) public read.

Sample - deny non-HTTPS and give another account read access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::ridaa-notes-2026",
        "arn:aws:s3:::ridaa-notes-2026/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    },
    {
      "Sid": "CrossAccountRead",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:root" },
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::ridaa-notes-2026",
        "arn:aws:s3:::ridaa-notes-2026/*"
      ]
    }
  ]
}
```

```bash
aws s3api put-bucket-policy --bucket ridaa-notes-2026 --policy file://bucket-policy.json
aws s3api get-bucket-policy --bucket ridaa-notes-2026 --query Policy --output text
aws s3api get-public-access-block --bucket ridaa-notes-2026
```

Block Public Access overrides any policy that would make the bucket public - that's the safety net, keep it on unless you really mean to host public content (and even then prefer CloudFront with OAC).

## Use cases

- Static website hosting (often S3 + CloudFront).
- Backups and disaster recovery, DB dumps, EBS snapshots under the hood.
- Data lake for analytics (Athena, Glue, EMR query directly on S3).
- Log storage - ALB, CloudTrail, VPC flow logs all write to S3.
- Artifact storage for CI/CD (build outputs, Docker layers via ECR uses S3).
- **Terraform remote state** - state file in S3 with `use_lockfile = true` (or DynamoDB locking on older setups).
- Media/user uploads for apps, served with presigned URLs.
