#############################################
# main.tf — Lab 02b: GitHub OIDC với AWS
# Mục tiêu:
# GitHub Actions → OIDC Token → AWS STS → IAM Role
#############################################

#############################################
# 1. Terraform & AWS Provider
#############################################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#############################################
# 2. Biến cấu hình
#############################################
variable "aws_region" {
  description = "AWS Region dùng cho lab"
  type        = string
  default     = "us-east-1"
}

variable "github_username" {
  description = "GitHub username của bạn"
  type        = string
}

variable "github_repo" {
  description = "Tên repository GitHub"
  type        = string
  default     = "action-test"
}

#############################################
# 3. GitHub OIDC Provider
# AWS sẽ tin token do GitHub phát hành
#############################################
# resource "aws_iam_openid_connect_provider" "github" {
#   url = "https://token.actions.githubusercontent.com"

#   # Token này sẽ được dùng để gọi STS
#   client_id_list = [
#     "sts.amazonaws.com"
#   ]

#   # Thumbprint của GitHub OIDC endpoint
#   thumbprint_list = [
#     "6938fd4d98bab03faadb97b34396831e3780aea1"
#   ]

#   tags = {
#     Project = "lab-oidc"
#     Owner   = "terraform-bootcamp"
#   }
# }

data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::302403761345:oidc-provider/token.actions.githubusercontent.com"
}


#############################################
# 4. IAM Role cho GitHub Actions
#############################################
resource "aws_iam_role" "gha_lab" {
  name = "lab-oidc-github-actions"

  ###########################################
  # Trust Policy (QUAN TRỌNG NHẤT)
  # Quy định AI được phép assume role này
  ###########################################
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"

        # Chỉ chấp nhận token từ GitHub OIDC
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {

          # Audience phải là STS
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          # Chỉ repo này được assume
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_username}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Project = "lab-oidc"
    Purpose = "GitHub Actions OIDC Lab"
  }
}

#############################################
# 5. Cấp quyền tối thiểu để test
#############################################
resource "aws_iam_role_policy_attachment" "readonly" {
  role       = aws_iam_role.gha_lab.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

#############################################
# 6. Outputs
#############################################
output "oidc_provider_arn" {
  description = "ARN của GitHub OIDC Provider"
  value       = data.aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_arn" {
  description = "ARN role dùng trong GitHub Actions workflow"
  value       = aws_iam_role.gha_lab.arn
}

output "trust_policy_subject" {
  description = "GitHub subject được phép assume role"
  value       = "repo:${var.github_username}/${var.github_repo}:*"
}