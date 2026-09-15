# terraform-aws-s3

Terraform module for an S3 bucket with public access blocked, versioning, and
server-side encryption (SSE-KMS by default) enabled out of the box.

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
| terraform | n/a |
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
| bucket | Name of the S3 bucket. If null, a unique name is generated. | `null` | no |
| block_public_acls | Whether Amazon S3 blocks public ACLs for this bucket. | `true` | no |
| block_public_policy | Whether Amazon S3 blocks public bucket policies for this bucket. | `true` | no |
| ignore_public_acls | Whether Amazon S3 ignores public ACLs for this bucket. | `true` | no |
| restrict_public_buckets | Whether Amazon S3 restricts public bucket policies for this bucket. | `true` | no |
| bucket_key_enabled | Whether to use S3 Bucket Keys to reduce SSE-KMS request costs. | `true` | no |
| kms_master_key_id | ARN of the KMS key used for SSE-KMS encryption. If null, the AWS managed key `aws/s3` is used. | `null` | no |
| sse_algorithm | Server-side encryption algorithm to use. Valid values: `AES256` or `aws:kms`. | `"aws:kms"` | no |
| versioning | Versioning state of the bucket. Valid values: `enabled`, `suspended`, or `disabled`. | `"enabled"` | no |
| tags | A map of tags to assign to the bucket. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| arn | The ARN of the S3 bucket. |
| bucket | The name of the S3 bucket. |
| region | The region of the S3 bucket. |

## License

MIT — see [LICENSE.md](LICENSE.md).
