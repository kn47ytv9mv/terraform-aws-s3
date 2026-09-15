variable "bucket" {
  default     = null
  description = "Name of the S3 bucket. If null, a unique name is generated."
}

variable "block_public_acls" {
  default     = true
  description = "Whether Amazon S3 blocks public ACLs for this bucket."
}

variable "block_public_policy" {
  default     = true
  description = "Whether Amazon S3 blocks public bucket policies for this bucket."
}

variable "ignore_public_acls" {
  default     = true
  description = "Whether Amazon S3 ignores public ACLs for this bucket."
}

variable "restrict_public_buckets" {
  default     = true
  description = "Whether Amazon S3 restricts public bucket policies for this bucket."
}

variable "bucket_key_enabled" {
  default     = true
  description = "Whether to use S3 Bucket Keys to reduce SSE-KMS request costs."
}

variable "kms_master_key_id" {
  default     = null
  description = "ARN of the KMS key used for SSE-KMS encryption. If null, the AWS managed key 'aws/s3' is used."
}

variable "sse_algorithm" {
  default     = "aws:kms"
  description = "Server-side encryption algorithm to use. Valid values: 'AES256' or 'aws:kms'."
}

variable "versioning" {
  default     = "enabled"
  description = "Versioning state of the bucket. Valid values: 'enabled', 'suspended', or 'disabled'."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the bucket."
}
