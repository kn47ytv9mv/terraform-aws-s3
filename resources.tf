resource "random_uuid" "resource" {

}

resource "aws_s3_bucket" "resource" {
  bucket = coalesce(var.bucket, random_uuid.resource.id)

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

output "arn" {
  value = aws_s3_bucket.resource.arn
}

output "bucket" {
  value = aws_s3_bucket.resource.id
}

output "region" {
  value = aws_s3_bucket.resource.region
}
