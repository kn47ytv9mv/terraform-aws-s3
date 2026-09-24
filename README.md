# terraform-aws-s3

Terraform module for an S3 bucket with public access blocked, versioning, and
server-side encryption (SSE-KMS by default) enabled out of the box.

## Cost

Amazon S3 bills for storage consumed and for requests made against the
bucket; there is no charge for the bucket itself when empty. Versioning
retains prior object versions, which adds to storage billed. See AWS's
[S3 pricing](https://aws.amazon.com/s3/pricing/) page for current rates.

## Design

**The default `sse_algorithm` (`"aws:kms"`) cannot be served through
S3 static website hosting** — website hosting serves only SSE-S3
(`AES256`) objects. Confirmed against real AWS: an anonymous GET
against a website endpoint for an SSE-KMS object fails with `400
InvalidRequest: The object was stored using a form of Server Side
Encryption. The correct parameters must be provided to retrieve the
object`. This module does not manage
`aws_s3_bucket_website_configuration` itself (it requires public
access, conflicting with this module's secure-by-default
`block_public_*` settings) — a caller adding one needs to override
`sse_algorithm = "AES256"` first, or every object served through the
website endpoint fails the same way.

### Switches that look redundant, and are not

`enable_access_logging` alongside `access_log_bucket` reads like a switch
you should not have to remember. It exists because **Terraform decides
how many resources to create before it knows any value AWS computes.**
Gating on `access_log_bucket != null` works only while the bucket name is
written literally in the configuration; point it at a bucket created in
the same apply and the plan fails outright with *"Invalid count argument
... cannot be determined until apply"*, because Terraform cannot yet tell
whether that name is null.

A boolean the caller writes is always known at plan time, so the gate
holds no matter where the bucket name comes from. Supplying one without
the other is rejected rather than silently ignored, in both directions.

### Object lock, and the one change you cannot undo

`object_lock_enabled` puts the bucket under object lock, so an
`object_lock_rule` can block deletion of every new object version for a
fixed period. **AWS accepts this flag only when the bucket is created.**
Setting it on a bucket that already exists therefore does not reconfigure
that bucket — Terraform plans to destroy and recreate it, and everything
in it goes with it. Read the plan before applying this to anything that
holds data. There is no validation that can catch this, because Terraform
cannot know whether the bucket already exists.

`mode` is the decision that matters. Under `GOVERNANCE` a caller holding
`s3:BypassGovernanceRetention` can remove a lock early, which makes it a
strong default that an administrator can still correct. Under
`COMPLIANCE` nobody can — not an administrator, not the account root —
until the retention period expires, and the objects keep accruing storage
charges for the whole of it. Choose `COMPLIANCE` when an auditor requires
it and not before.

Object lock requires versioning, which this module enables by default. A
rule is optional: enabling the lock without one leaves retention to be
set per object.

### Replication

`enable_replication` copies objects to one or more destination buckets,
which is how a bucket survives losing its region. Three things are worth
knowing before turning it on.

**It needs a role this module does not create.** S3 assumes
`replication_role_arn` to read from this bucket and write to every
destination; build it with
[`terraform-aws-iam-role`](https://github.com/kn47ytv9mv/terraform-aws-iam-role).
Without the right permissions replication fails quietly, object by
object, rather than failing the apply.

**Versioning is required on the destination too**, not only here. A
destination bucket built by this module has it by default; one built
elsewhere may not, and replication to it will not work.

**`delete_marker_replication` defaults to false, deliberately.** It is
the setting that turns replication from a backup into a mirror: with it
on, deleting an object here deletes it there, which is exactly what you
do not want from a copy kept for recovery. Turn it on only when you
genuinely want the destination to track deletions.

Rules are keyed by a name you choose, and the key becomes the rule ID, so
adding a rule leaves the others untouched.

## Usage

```hcl
module "bucket" {
  source = "kn47ytv9mv/s3/aws"
}
```

Or directly from this repository:

```hcl
module "bucket" {
  source = "github.com/kn47ytv9mv/terraform-aws-s3"
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.9 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| bucket | The name of the S3 bucket. If null, a unique name is generated. | `null` | no |
| block_public_acls | Whether Amazon S3 blocks public ACLs for this bucket. | `true` | no |
| block_public_policy | Whether Amazon S3 blocks public bucket policies for this bucket. | `true` | no |
| ignore_public_acls | Whether Amazon S3 ignores public ACLs for this bucket. | `true` | no |
| restrict_public_buckets | Whether Amazon S3 restricts public bucket policies for this bucket. | `true` | no |
| bucket_key_enabled | Whether to use S3 Bucket Keys to reduce SSE-KMS request costs. | `true` | no |
| kms_master_key_id | The ARN of the KMS key used for SSE-KMS encryption. If null, the AWS managed key `aws/s3` is used. | `null` | no |
| sse_algorithm | Server-side encryption algorithm to use (e.g. `'AES256'` or `'aws:kms'`). | `"aws:kms"` | no |
| versioning | Versioning state of the bucket (e.g. `'enabled'`, `'suspended'`, or `'disabled'`). | `"enabled"` | no |
| tags | A map of tags to assign to the bucket. | `null` | no |
| enable_access_logging | Whether this bucket delivers server access logs to `access_log_bucket`. Separate from the bucket name because Terraform needs the decision known at plan time — see Design. | `false` | no |
| access_log_bucket | Name of a separate S3 bucket receiving this bucket's server access logs. Requires `enable_access_logging`. Must not be this bucket itself. | `null` | no |
| object_lock_enabled | Whether the bucket is created with object lock, permitting a retention rule that blocks deletion. AWS accepts this only at creation, so enabling it on an existing bucket **replaces the bucket and destroys its contents** — see Design. Requires versioning. | `false` | no |
| object_lock_rule | Default retention applied to every new object version. `mode` is `'GOVERNANCE'` or `'COMPLIANCE'`; set exactly one of `days` or `years`. If null, object lock is enabled with no default rule. | `null` | no |
| enable_replication | Whether the bucket replicates objects to another bucket. Separate from the role and rules because Terraform needs the decision known at plan time — see Design. Requires versioning here and on every destination. | `false` | no |
| replication_role_arn | ARN of the IAM role S3 assumes to replicate, from `terraform-aws-iam-role`. This module does not create it. Requires `enable_replication`. | `null` | no |
| replication_rules | Replication rules keyed by a name you choose, which becomes the rule ID. Each needs `destination_bucket_arn`. `delete_marker_replication` defaults false, since it is what makes replication destructive. | `{}` | no |
| access_log_prefix | Prefix for access log object keys in `access_log_bucket`. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| bucket | The name of the S3 bucket. |
| arn | The ARN of the S3 bucket. |
| region | The region of the S3 bucket. |
| replication_rule_ids | IDs of the replication rules created, as supplied in `replication_rules`. Empty when replication is disabled. |

## License

MIT — see [LICENSE.md](LICENSE.md).
