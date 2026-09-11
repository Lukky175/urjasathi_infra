output "ec2_instance_id" {

  description = "UrjaSathi EC2 instance ID"

  value = aws_instance.urjasathi.id
}


output "ec2_public_ip" {

  description = "UrjaSathi EC2 public IP"

  value = aws_instance.urjasathi.public_ip
}


output "ec2_public_dns" {

  description = "UrjaSathi EC2 public DNS"

  value = aws_instance.urjasathi.public_dns
}


output "github_deploy_role_arn" {

  description = "IAM role used by GitHub Actions"

  value = aws_iam_role.github_deploy.arn
}