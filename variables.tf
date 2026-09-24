variable "bucket" {
  default     = null
  description = "The name of the S3 bucket. If null, a unique name is generated."
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
  description = "The ARN of the KMS key used for SSE-KMS encryption. If null, the AWS managed key 'aws/s3' is used."
}

variable "sse_algorithm" {
  default     = "aws:kms"
  description = "Server-side encryption algorithm to use (e.g. 'AES256' or 'aws:kms')."
}

variable "versioning" {
  default     = "enabled"
  description = "Versioning state of the bucket (e.g. 'enabled', 'suspended', or 'disabled')."
}

variable "enable_access_logging" {
  default     = false
  description = "Whether this bucket delivers server access logs to access_log_bucket. This is a separate switch because Terraform requires the decision to be known before it plans, and a target bucket created in the same configuration is not — see the Design section."

  validation {
    condition     = !var.enable_access_logging || var.access_log_bucket != null
    error_message = "enable_access_logging requires access_log_bucket to name the bucket receiving the logs."
  }

  validation {
    condition     = var.access_log_bucket == null || var.enable_access_logging
    error_message = "access_log_bucket is set but enable_access_logging is false, so no logs would be delivered. Set enable_access_logging = true."
  }
}

variable "access_log_bucket" {
  default     = null
  description = "Name of a separate S3 bucket receiving this bucket's server access logs, one record per request. Requires enable_access_logging. Server access logging costs nothing beyond the storage the logs occupy. The target bucket must grant write access to the S3 log delivery group, and must not be this bucket itself, which would log its own log writes indefinitely."
}

variable "access_log_prefix" {
  default     = null
  description = "Prefix for access log object keys in access_log_bucket. Only used when access_log_bucket is set."
}

variable "object_lock_enabled" {
  default     = false
  description = "Whether the bucket is created with object lock, permitting a retention rule that blocks deletion. AWS accepts this only at bucket creation, so enabling it on a bucket that already exists replaces the bucket and destroys its contents — see the Design section. Requires versioning."

  validation {
    condition     = !var.object_lock_enabled || lower(var.versioning) == "enabled"
    error_message = "object_lock_enabled requires versioning to be 'enabled'. Object lock protects specific object versions, so a bucket without versioning has nothing to lock."
  }
}

variable "object_lock_rule" {
  default     = null
  description = "Default retention applied to every new object version. mode is 'GOVERNANCE' (a privileged caller may remove the lock) or 'COMPLIANCE' (nobody may, including the account root, until it expires). Set exactly one of days or years. If null, object lock is enabled with no default rule and retention is set per object."
  type = object({
    mode  = string
    days  = optional(number)
    years = optional(number)
  })

  validation {
    condition     = var.object_lock_rule == null || contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_rule.mode)
    error_message = "object_lock_rule.mode must be 'GOVERNANCE' or 'COMPLIANCE'."
  }

  validation {
    condition     = var.object_lock_rule == null || ((var.object_lock_rule.days == null) != (var.object_lock_rule.years == null))
    error_message = "Set exactly one of object_lock_rule.days or object_lock_rule.years. AWS rejects both together and a rule with neither."
  }
}

variable "enable_replication" {
  default     = false
  description = "Whether the bucket replicates objects to another bucket. This is a separate switch because Terraform requires the decision to be known before it plans, and a role ARN created in the same configuration is not — see the Design section. Requires versioning on this bucket and on every destination."

  validation {
    condition     = !var.enable_replication || var.replication_role_arn != null
    error_message = "enable_replication requires replication_role_arn. S3 assumes that role to read from this bucket and write to the destination."
  }

  validation {
    condition     = !var.enable_replication || length(var.replication_rules) > 0
    error_message = "enable_replication requires at least one entry in replication_rules. Replication with no rule copies nothing."
  }

  validation {
    condition     = !var.enable_replication || lower(var.versioning) == "enabled"
    error_message = "enable_replication requires versioning to be 'enabled'. S3 replicates object versions, so an unversioned bucket cannot be a replication source."
  }
}

variable "replication_role_arn" {
  default     = null
  description = "ARN of the IAM role S3 assumes to replicate objects, from terraform-aws-iam-role. The role needs read access to this bucket and write access to every destination; this module does not create it. Requires enable_replication."
}

variable "replication_rules" {
  default     = {}
  description = <<-EOT
    Replication rules, keyed by a name you choose. The key identifies the rule in state and becomes its ID, so adding one leaves the others untouched — and it must be a value you write, not one read from another resource.

    destination_bucket_arn is required. storage_class defaults to AWS's own choice. replica_kms_key_id is required when the destination applies SSE-KMS, and pairs with sse_kms_encrypted_objects to replicate objects this bucket encrypted with KMS. prefix limits the rule to a key prefix; delete_marker_replication copies deletions, which is off by default because it is the setting that makes replication destructive.
  EOT
  type = map(object({
    destination_bucket_arn      = string
    storage_class               = optional(string)
    replica_kms_key_id          = optional(string)
    sse_kms_encrypted_objects   = optional(bool, false)
    prefix                      = optional(string)
    priority                    = optional(number)
    delete_marker_replication   = optional(bool, false)
    existing_object_replication = optional(bool, false)
  }))
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the bucket."
}
