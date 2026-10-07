# IAM - Identity and Access Management

Name: Ridaa Mirza
Enrollment No: 24BCS10394

## What is IAM

IAM is the AWS service that decides **who** can do **what** on **which** resource. Every API call to AWS (console click, CLI command, Terraform apply) gets checked against IAM first. It's a global service - not tied to a region - and it's free.

Two words that keep coming up:

- **Authentication** - proving who you are (password, access keys, MFA).
- **Authorization** - what you're allowed to do once AWS knows who you are (policies).

## Root user vs IAM users

When you create an AWS account you get the **root user** (the email you signed up with). Root can do literally everything, including closing the account. The rule is: lock it with MFA and don't use it for day-to-day work. Create IAM identities instead.

## Users

An IAM user is a long-lived identity for one person or one application.

- Can have a console password (for humans).
- Can have access keys (`AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`) for the CLI/SDK/Terraform.
- Has no permissions by default - everything is denied until a policy allows it.

```bash
aws iam create-user --user-name ridaa-dev
aws iam create-login-profile --user-name ridaa-dev --password 'TempPass#123' --password-reset-required
aws iam create-access-key --user-name ridaa-dev
aws iam list-users
```

## Groups

A group is just a collection of users. You attach policies to the group and every user in it inherits them. Way easier than attaching the same policy to 20 users one by one.

- A user can be in multiple groups.
- Groups can't contain other groups.
- A group is not an identity - you can't log in as a group.

```bash
aws iam create-group --group-name developers
aws iam add-user-to-group --group-name developers --user-name ridaa-dev
aws iam attach-group-policy --group-name developers \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
aws iam list-groups-for-user --user-name ridaa-dev
```

## Roles

A role is an identity with permissions but **no long-term credentials**. Something "assumes" the role and gets temporary credentials from STS that expire (default 1 hour).

Who assumes roles:

- AWS services - e.g. an EC2 instance that needs to read S3, a Lambda that writes to DynamoDB.
- Users from another AWS account (cross-account access).
- Federated users (SSO, Google/GitHub login via OIDC - e.g. GitHub Actions deploying to AWS without stored keys).

A role has two parts:

1. **Trust policy** - who is allowed to assume it.
2. **Permissions policy** - what it can do once assumed.

Trust policy that lets EC2 assume a role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

```bash
aws iam create-role --role-name ec2-s3-reader \
  --assume-role-policy-document file://trust-ec2.json
aws iam attach-role-policy --role-name ec2-s3-reader \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# EC2 needs an instance profile wrapper around the role
aws iam create-instance-profile --instance-profile-name ec2-s3-reader
aws iam add-role-to-instance-profile --instance-profile-name ec2-s3-reader --role-name ec2-s3-reader

# assume a role manually and get temp creds
aws sts assume-role --role-arn arn:aws:iam::123456789012:role/ec2-s3-reader --role-session-name test
```

## Policies

A policy is a JSON document that lists permissions. Types:

| Type | What it is |
|------|-----------|
| AWS managed | Written and maintained by AWS (e.g. `AmazonS3ReadOnlyAccess`, `AdministratorAccess`) |
| Customer managed | Written by you, reusable across users/groups/roles |
| Inline | Embedded directly in one user/group/role, deleted with it |
| Resource-based | Attached to the resource instead of the identity (e.g. S3 bucket policy, SQS queue policy) |
| Permission boundary | Max permissions an identity can ever get, even if other policies allow more |

### Sample policy - read/write to one bucket only

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOnlyMyBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::ridaa-tf-demo-*"
    },
    {
      "Sid": "ReadWriteObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::ridaa-tf-demo-*/*"
    },
    {
      "Sid": "DenyIfNoMFAForDelete",
      "Effect": "Deny",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::ridaa-tf-demo-*/*",
      "Condition": {
        "BoolIfExists": { "aws:MultiFactorAuthPresent": "false" }
      }
    }
  ]
}
```

Parts of a statement:

- **Effect** - `Allow` or `Deny`.
- **Action** - API calls, `service:Operation` (wildcards allowed, e.g. `s3:Get*`).
- **Resource** - ARNs the statement applies to. Note `ListBucket` is on the bucket ARN, but `GetObject` is on `bucket/*` - easy to get wrong.
- **Condition** - optional extra checks (MFA, source IP, tags, region...).
- **Principal** - only in resource-based and trust policies (who the policy is about).

```bash
aws iam create-policy --policy-name s3-demo-rw --policy-document file://s3-demo-rw.json
aws iam attach-user-policy --user-name ridaa-dev \
  --policy-arn arn:aws:iam::123456789012:policy/s3-demo-rw
aws iam list-attached-user-policies --user-name ridaa-dev
```

## Permissions - how AWS evaluates them

1. Everything starts as **implicit deny**.
2. If any policy has an **explicit Deny** that matches - denied. Explicit deny always wins.
3. Else if some policy has an **Allow** that matches - allowed.
4. Else - still denied (implicit).

So `Deny` > `Allow` > default deny. On top of that, SCPs (from AWS Organizations) and permission boundaries can cap what's allowed.

Handy for testing without actually calling the API:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/ridaa-dev \
  --action-names s3:GetObject s3:DeleteBucket \
  --resource-arns arn:aws:s3:::ridaa-tf-demo-abc123/file.txt
```

## Least privilege

Give an identity only the permissions it needs to do its job, nothing extra. Practically:

- Start with nothing and add actions as you hit `AccessDenied`, not the other way around.
- Scope `Resource` to specific ARNs instead of `"*"`.
- Avoid `AdministratorAccess` / `"Action": "*"` for anything that isn't a break-glass admin.
- Use IAM Access Analyzer to generate a policy from actual CloudTrail activity and to find unused permissions.

## Best practices

- Turn on MFA for root and every human user. Don't create access keys for root.
- Use roles + temporary credentials instead of long-lived access keys wherever possible (EC2 instance profiles, Lambda execution roles, GitHub OIDC).
- Manage permissions through groups, not per-user.
- Rotate access keys if you must have them; delete unused ones (`aws iam get-access-key-last-used`).
- Strong password policy.
- Never commit keys to git (that's why `terraform.tfvars` in this session has none).
- Use IAM Identity Center (SSO) for humans in bigger setups.
- Monitor with CloudTrail; review with the credential report.

```bash
aws iam update-account-password-policy --minimum-password-length 14 \
  --require-symbols --require-numbers --require-uppercase-characters --require-lowercase-characters
aws iam generate-credential-report
aws iam get-credential-report --query Content --output text | base64 --decode
```

## Common use cases

- Developers group with read-only prod access, full dev access.
- EC2 instance role so the app reads from S3 without any keys on the box.
- Lambda execution role that can only write to one DynamoDB table.
- CI/CD (GitHub Actions / Jenkins) assuming a deploy role via OIDC.
- Cross-account access - e.g. a security/audit account reading logs from all other accounts.
- A dedicated `terraform` user/role with just enough permissions to manage the infra in this repo.
