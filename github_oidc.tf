# 1. Establish the global trust connection between GitHub and your AWS Account
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # Standard GitHub secure certificate thumbprint
}

# 2. Create the specific role that your deployment pipeline will wear
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-deployment-role"

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
            # CRITICAL: This locks the security role down so ONLY your exact repository can use it!
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Replace 'YOUR_GITHUB_USERNAME' with your actual GitHub account name
            "token.actions.githubusercontent.com:sub" = "repo:Kush999/devops-core-app:*"
          }
        }
      }
    ]
  })
}

# 3. Give this role the power to read/write to your ECR Docker warehouse
resource "aws_iam_role_policy_attachment" "github_ecr_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Output the exact Role ARN string so you can easily copy it for the next step
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "Copy this ARN value directly into your GitHub actions workflow file!"
}