# 1. Definisikan GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c58a3a8516e8ec0eb215a31a38d7b3b72445f1b", "6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# 2. Buat IAM Role dengan Trust Policy Terbatas ke Repositori Anda
resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsTerraformRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # MODIFIKASI BAGIAN INI: Batasi hanya untuk repositori spesifik Anda
            "token.actions.githubusercontent.com:sub" = "repo:nazifbariq/cloud-security-lab:*"
          }
        }
      }
    ]
  })
}

# 3. Berikan Izin Administrator Terbatas pada Role Tersebut untuk Operasional Terraform
resource "aws_iam_role_policy_attachment" "github_admin_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Output ARN Role untuk digunakan di GitHub Actions Workflow
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "Salin ARN ini untuk konfigurasi workflow GitHub Actions"
}
