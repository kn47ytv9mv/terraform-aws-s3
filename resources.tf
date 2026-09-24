resource "random_uuid" "resource" {}

resource "aws_s3_bucket" "resource" {
  bucket              = coalesce(var.bucket, random_uuid.resource.id)
  object_lock_enabled = var.object_lock_enabled

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "resource" {
  bucket = aws_s3_bucket.resource.id

  versioning_configuration {
    status = title(lower(var.versioning))
  }
}

resource "aws_s3_bucket_public_access_block" "resource" {
  bucket = aws_s3_bucket.resource.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_server_side_encryption_configuration" "resource" {
  bucket = aws_s3_bucket.resource.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_master_key_id
      sse_algorithm     = var.sse_algorithm
    }

    bucket_key_enabled = var.bucket_key_enabled
  }
}

resource "aws_s3_bucket_logging" "resource" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = aws_s3_bucket.resource.id
  target_bucket = var.access_log_bucket
  target_prefix = var.access_log_prefix != null ? var.access_log_prefix : ""
}

resource "aws_s3_bucket_object_lock_configuration" "resource" {
  count = var.object_lock_enabled && var.object_lock_rule != null ? 1 : 0

  bucket = aws_s3_bucket.resource.id

  rule {
    default_retention {
      mode  = var.object_lock_rule.mode
      days  = var.object_lock_rule.days
      years = var.object_lock_rule.years
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "resource" {
  count = var.enable_replication ? 1 : 0

  bucket = aws_s3_bucket.resource.id
  role   = var.replication_role_arn

  dynamic "rule" {
    for_each = var.replication_rules

    content {
      id       = rule.key
      status   = "Enabled"
      priority = rule.value.priority

      filter {
        prefix = rule.value.prefix
      }

      delete_marker_replication {
        status = rule.value.delete_marker_replication ? "Enabled" : "Disabled"
      }

      dynamic "existing_object_replication" {
        for_each = rule.value.existing_object_replication ? [true] : []

        content {
          status = "Enabled"
        }
      }

      dynamic "source_selection_criteria" {
        for_each = rule.value.sse_kms_encrypted_objects ? [true] : []

        content {
          sse_kms_encrypted_objects {
            status = "Enabled"
          }
        }
      }

      destination {
        bucket        = rule.value.destination_bucket_arn
        storage_class = rule.value.storage_class

        dynamic "encryption_configuration" {
          for_each = rule.value.replica_kms_key_id != null ? [rule.value.replica_kms_key_id] : []

          content {
            replica_kms_key_id = encryption_configuration.value
          }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.resource]
}

output "bucket" {
  description = "The name of the S3 bucket."
  value       = aws_s3_bucket.resource.id
}

output "arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.resource.arn
}

output "region" {
  description = "The region of the S3 bucket."
  value       = aws_s3_bucket.resource.region
}

output "replication_rule_ids" {
  description = "IDs of the replication rules created, as supplied in replication_rules. Empty when replication is disabled."
  value       = var.enable_replication ? keys(var.replication_rules) : []
}
