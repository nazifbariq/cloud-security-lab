# 1. S3 Bucket menampung tfstate
resource "aws_s3_bucket" "terraform_state" {
	bucket			= "storage-tfstate-najip-cloud-lab"
	force_destroy	= false
}

resource "aws_s3_bucket_versioning" "state_versioning" {
	bucket			= aws_s3_bucket.terraform_state.id
	versioning_configuration {
		status = "Enabled"
	}
}

#Enkripsi server
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
	bucket	= aws_s3_bucket.terraform_state.id
	rule {
		apply_server_side_encryption_by_default {
		sse_algorithm = "AES256"
		}
	}
}

# 2. DynamoDB Table untuk State Locking
#resource "aws_iam_role_policy_attachment" "github_admin_attach" {
  # (Konfigurasi ini terpisah, fokus ke DynamoDB bawah)
#}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-lab-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID" # WAJIB persis seperti ini (Case-Sensitive)

  attribute {
    name = "LockID"
    type = "S"
  }
}
