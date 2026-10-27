resource "aws_s3_bucket" "production" {
  bucket = var.bucket_name
  tags   = { Name = var.bucket_name, Environment = "production" }
}

resource "aws_s3_bucket_public_access_block" "production" {
  bucket                  = aws_s3_bucket.production.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "production" {
  bucket = aws_s3_bucket.production.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_versioning" "production" {
  bucket = aws_s3_bucket.production.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "production" {
  bucket = aws_s3_bucket.production.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}
