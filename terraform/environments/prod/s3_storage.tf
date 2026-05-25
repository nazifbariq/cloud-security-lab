# --- 1. S3 Bucket untuk Archive Log ---
resource "aws_s3_bucket" "wazuh_archives" {
  bucket = "wazuh-logs-archive-${random_id.suffix.hex}" # Nama bucket harus unik secara global
  force_destroy = true # Memungkinkan penghapusan bucket meskipun ada isinya (untuk lab)

  tags = {
    Name = "Wazuh-Log-Archive"
    Environment = "Production-Sim"
  }
}

# Generate ID unik untuk nama bucket
resource "random_id" "suffix" {
  byte_length = 4
}

# --- 2. Security: Blokir akses publik ke S3 ---
resource "aws_s3_bucket_public_access_block" "wazuh_s3_block" {
  bucket = aws_s3_bucket.wazuh_archives.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- 3. IAM Policy: Izin untuk Upload ke S3 ---
resource "aws_iam_policy" "wazuh_s3_upload_policy" {
  name        = "WazuhS3UploadPolicy"
  description = "Allow Wazuh Manager to upload logs to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.wazuh_archives.arn}",
          "${aws_s3_bucket.wazuh_archives.arn}/*"
        ]
      }
    ]
  })
}

# --- 4. IAM Role untuk EC2 ---
resource "aws_iam_role" "wazuh_manager_role" {
  name = "WazuhManagerS3Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Tempelkan Policy ke Role
resource "aws_iam_role_policy_attachment" "wazuh_attach" {
  role       = aws_iam_role.wazuh_manager_role.name
  policy_arn = aws_iam_policy.wazuh_s3_upload_policy.arn
}

# --- 5. Instance Profile (Jembatan ke EC2) ---
resource "aws_iam_instance_profile" "wazuh_manager_profile" {
  name = "WazuhManagerInstanceProfile"
  role = aws_iam_role.wazuh_manager_role.name
}

# Output Nama Bucket untuk konfigurasi script nanti
output "s3_bucket_name" {
  value = aws_s3_bucket.wazuh_archives.id
}
