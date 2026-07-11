# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket ───
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "logs" {
  bucket        = "devsecops-l3-logs-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "s3-logs-devsecops"
  }
}

# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block ───
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration ───
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning ───
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}
