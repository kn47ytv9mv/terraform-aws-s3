mock_provider "aws" {
}

run "default_config_creates_expected_resources" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.resource.versioning_configuration[0].status == "Enabled"
    error_message = "Default versioning ('enabled') should map to the 'Enabled' status AWS expects."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.resource.block_public_acls == true
    error_message = "Public access should be blocked by default."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.resource.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "SSE-KMS should be the default encryption algorithm."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.resource.rule).bucket_key_enabled == true
    error_message = "Bucket keys should be enabled by default to reduce SSE-KMS request costs."
  }
}

run "bucket_name_generated_when_unset" {
  command = apply

  assert {
    condition     = aws_s3_bucket.resource.bucket == random_uuid.resource.id
    error_message = "Leaving bucket unset should fall back to the generated random_uuid."
  }
}

run "bucket_name_explicit_overrides_generated" {
  command = plan

  variables {
    bucket = "my-explicit-bucket-name"
  }

  assert {
    condition     = aws_s3_bucket.resource.bucket == "my-explicit-bucket-name"
    error_message = "An explicit bucket name should be used as-is instead of the generated one."
  }
}

run "versioning_status_mapping" {
  command = plan

  variables {
    versioning = "suspended"
  }

  assert {
    condition     = aws_s3_bucket_versioning.resource.versioning_configuration[0].status == "Suspended"
    error_message = "versioning = 'suspended' should map to the 'Suspended' status AWS expects."
  }
}

run "public_access_block_can_be_relaxed" {
  command = plan

  variables {
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
  }

  assert {
    condition     = !aws_s3_bucket_public_access_block.resource.block_public_acls
    error_message = "Public access block settings should pass through as configured, including when relaxed."
  }
}

run "kms_master_key_id_passthrough" {
  command = plan

  variables {
    kms_master_key_id = "arn:aws:kms:us-east-1:123456789012:key/example"
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.resource.rule).apply_server_side_encryption_by_default).kms_master_key_id == "arn:aws:kms:us-east-1:123456789012:key/example"
    error_message = "An explicit kms_master_key_id should be passed through to the encryption configuration."
  }
}

run "no_access_logging_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_logging.resource) == 0
    error_message = "Leaving access_log_bucket unset should create no logging resource."
  }
}

run "supplying_a_bucket_enables_access_logging" {
  command = plan

  variables {
    enable_access_logging = true
    access_log_bucket     = "audit-logs"
    access_log_prefix     = "s3/"
  }

  assert {
    condition     = length(aws_s3_bucket_logging.resource) == 1
    error_message = "Supplying a target bucket should create exactly one logging resource."
  }

  assert {
    condition     = aws_s3_bucket_logging.resource[0].target_bucket == "audit-logs"
    error_message = "The target bucket should pass through unchanged."
  }
}

run "access_log_prefix_defaults_to_empty_string" {
  command = plan

  variables {
    enable_access_logging = true
    access_log_bucket     = "audit-logs"
  }

  assert {
    condition     = aws_s3_bucket_logging.resource[0].target_prefix == ""
    error_message = "AWS requires target_prefix, so an unset prefix should become an empty string rather than null."
  }
}

run "readme_default_minimal" {
  command = plan
}

run "enable_access_logging_without_access_log_bucket_is_rejected" {
  command = plan

  variables {
    enable_access_logging = true
  }

  expect_failures = [var.enable_access_logging]
}

run "access_log_bucket_without_enable_access_logging_is_rejected" {
  command = plan

  variables {
    access_log_bucket = "audit-logs"
  }

  expect_failures = [var.enable_access_logging]
}

run "the_defaults_create_neither_object_lock_nor_replication" {
  command = plan

  assert {
    condition     = aws_s3_bucket.resource.object_lock_enabled == false
    error_message = "A bucket should not be created with object lock unless asked, because enabling it later replaces the bucket."
  }

  assert {
    condition     = length(aws_s3_bucket_object_lock_configuration.resource) == 0
    error_message = "No object lock configuration should exist by default."
  }

  assert {
    condition     = length(aws_s3_bucket_replication_configuration.resource) == 0
    error_message = "No replication configuration should exist by default."
  }

  assert {
    condition     = length(output.replication_rule_ids) == 0
    error_message = "With replication disabled there are no rule IDs to report."
  }
}

run "object_lock_without_versioning_is_rejected" {
  command = plan

  variables {
    object_lock_enabled = true
    versioning          = "disabled"
  }

  expect_failures = [var.object_lock_enabled]
}

run "an_object_lock_rule_with_both_days_and_years_is_rejected" {
  command = plan

  variables {
    object_lock_enabled = true
    object_lock_rule    = { mode = "GOVERNANCE", days = 30, years = 1 }
  }

  expect_failures = [var.object_lock_rule]
}

run "an_object_lock_rule_with_neither_days_nor_years_is_rejected" {
  command = plan

  variables {
    object_lock_enabled = true
    object_lock_rule    = { mode = "GOVERNANCE" }
  }

  expect_failures = [var.object_lock_rule]
}

run "an_unknown_object_lock_mode_is_rejected" {
  command = plan

  variables {
    object_lock_enabled = true
    object_lock_rule    = { mode = "STRICT", days = 30 }
  }

  expect_failures = [var.object_lock_rule]
}

run "object_lock_with_a_compliance_rule_creates_the_configuration" {
  command = plan

  variables {
    object_lock_enabled = true
    object_lock_rule    = { mode = "COMPLIANCE", years = 7 }
  }

  assert {
    condition     = aws_s3_bucket.resource.object_lock_enabled == true
    error_message = "The bucket itself must carry object_lock_enabled, since AWS accepts it only at creation."
  }

  assert {
    condition     = aws_s3_bucket_object_lock_configuration.resource[0].rule[0].default_retention[0].mode == "COMPLIANCE"
    error_message = "The retention mode should pass through unchanged."
  }

  assert {
    condition     = aws_s3_bucket_object_lock_configuration.resource[0].rule[0].default_retention[0].years == 7
    error_message = "The retention period should pass through unchanged."
  }
}

run "object_lock_enabled_without_a_rule_locks_the_bucket_but_sets_no_default" {
  command = plan

  variables {
    object_lock_enabled = true
  }

  assert {
    condition     = aws_s3_bucket.resource.object_lock_enabled == true
    error_message = "The bucket should still be created with object lock so retention can be set per object."
  }

  assert {
    condition     = length(aws_s3_bucket_object_lock_configuration.resource) == 0
    error_message = "Without a rule there is no default retention to configure."
  }
}

run "replication_without_a_role_is_rejected" {
  command = plan

  variables {
    enable_replication = true
    replication_rules  = { backup = { destination_bucket_arn = "arn:aws:s3:::dr-bucket" } }
  }

  expect_failures = [var.enable_replication]
}

run "replication_without_rules_is_rejected" {
  command = plan

  variables {
    enable_replication   = true
    replication_role_arn = "arn:aws:iam::123456789012:role/replication"
  }

  expect_failures = [var.enable_replication]
}

run "replication_without_versioning_is_rejected" {
  command = plan

  variables {
    enable_replication   = true
    replication_role_arn = "arn:aws:iam::123456789012:role/replication"
    replication_rules    = { backup = { destination_bucket_arn = "arn:aws:s3:::dr-bucket" } }
    versioning           = "disabled"
  }

  expect_failures = [var.enable_replication]
}

run "replication_creates_one_rule_per_key_with_deletions_off" {
  command = plan

  variables {
    enable_replication   = true
    replication_role_arn = "arn:aws:iam::123456789012:role/replication"

    replication_rules = {
      dr      = { destination_bucket_arn = "arn:aws:s3:::dr-bucket", storage_class = "STANDARD_IA" }
      archive = { destination_bucket_arn = "arn:aws:s3:::archive-bucket", prefix = "logs/" }
    }
  }

  assert {
    condition     = length(aws_s3_bucket_replication_configuration.resource) == 1
    error_message = "Enabling replication should create exactly one replication configuration."
  }

  assert {
    condition     = length(aws_s3_bucket_replication_configuration.resource[0].rule) == 2
    error_message = "Each key in replication_rules should become one rule."
  }

  assert {
    condition     = length(output.replication_rule_ids) == 2
    error_message = "Both rule IDs should be reported."
  }

  assert {
    condition     = alltrue([for r in aws_s3_bucket_replication_configuration.resource[0].rule : r.delete_marker_replication[0].status == "Disabled"])
    error_message = "Delete marker replication should stay off unless asked, because it is what makes replication destructive."
  }
}

run "replicating_deletions_is_opt_in" {
  command = plan

  variables {
    enable_replication   = true
    replication_role_arn = "arn:aws:iam::123456789012:role/replication"

    replication_rules = {
      dr = { destination_bucket_arn = "arn:aws:s3:::dr-bucket", delete_marker_replication = true }
    }
  }

  assert {
    condition     = aws_s3_bucket_replication_configuration.resource[0].rule[0].delete_marker_replication[0].status == "Enabled"
    error_message = "Asking for delete marker replication should enable it."
  }
}
