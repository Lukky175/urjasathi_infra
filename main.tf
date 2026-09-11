terraform {

  required_version = ">= 1.6.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

  }

}


# ============================================================
# AWS
# ============================================================

provider "aws" {
  region = var.aws_region
}


# ============================================================
# DEFAULT VPC
# ============================================================

data "aws_vpc" "default" {

  default = true

}


data "aws_subnets" "default" {

  filter {

    name = "vpc-id"

    values = [
      data.aws_vpc.default.id
    ]

  }

}


# ============================================================
# UBUNTU AMI
# ============================================================

data "aws_ami" "ubuntu" {

  most_recent = true

  owners = [
    "099720109477"
  ]

  filter {

    name = "name"

    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    ]

  }

  filter {

    name = "architecture"

    values = [
      "x86_64"
    ]

  }

  filter {

    name = "virtualization-type"

    values = [
      "hvm"
    ]

  }

}


# ============================================================
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "urjasathi" {

  name        = "${var.project_name}-sg"
  description = "Security group for UrjaSathi"
  vpc_id      = data.aws_vpc.default.id


  # ----------------------------------------------------------
  # HTTP
  # ----------------------------------------------------------

  ingress {

    description = "HTTP"

    from_port = 80
    to_port   = 80

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]

  }


  # ----------------------------------------------------------
  # NO SSH
  #
  # Access is through AWS Systems Manager.
  # ----------------------------------------------------------


  # ----------------------------------------------------------
  # OUTBOUND
  # ----------------------------------------------------------

  egress {

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]

  }


  tags = {

    Name    = "${var.project_name}-sg"
    Project = var.project_name

  }

}


# ============================================================
# EC2 IAM ROLE
#
# Allows EC2 to communicate with Systems Manager.
# ============================================================

resource "aws_iam_role" "ec2_ssm" {

  name = "${var.project_name}-ec2-ssm-role"


  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Principal = {

          Service = "ec2.amazonaws.com"

        }

        Action = "sts:AssumeRole"

      }

    ]

  })

}


resource "aws_iam_role_policy_attachment" "ec2_ssm" {

  role = aws_iam_role.ec2_ssm.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}


resource "aws_iam_instance_profile" "ec2" {

  name = "${var.project_name}-ec2-profile"

  role = aws_iam_role.ec2_ssm.name

}


# ============================================================
# EC2
# ============================================================

resource "aws_instance" "urjasathi" {

  ami = data.aws_ami.ubuntu.id

  instance_type = var.instance_type

  subnet_id = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [
    aws_security_group.urjasathi.id
  ]

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  user_data = file("${path.module}/user-data.sh")

  user_data_replace_on_change = true


  root_block_device {

    volume_size = 30

    volume_type = "gp3"

    delete_on_termination = true

  }


  tags = {

    Name    = var.project_name
    Project = var.project_name

  }

}


# ============================================================
# GITHUB ACTIONS OIDC
# ============================================================

data "tls_certificate" "github" {

  url = "https://token.actions.githubusercontent.com"

}


resource "aws_iam_openid_connect_provider" "github" {

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint
  ]

}


# ============================================================
# URJASATHI APPLICATION DEPLOYMENT ROLE
#
# This role is ONLY for:
#
# Lukky175/urjasathi
#
# It allows GitHub Actions from the application repository
# to deploy containers to the EC2 instance through SSM.
# ============================================================

resource "aws_iam_role" "urjasathi_app_deploy" {

  name = "${var.project_name}-app-deploy"


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

            "token.actions.githubusercontent.com:sub" = "repo:${var.app_repository}:*"

          }

        }

      }

    ]

  })

}


# ============================================================
# APPLICATION REPOSITORY → SSM PERMISSIONS
# ============================================================

resource "aws_iam_role_policy" "urjasathi_app_deploy" {

  name = "${var.project_name}-app-deploy-policy"

  role = aws_iam_role.urjasathi_app_deploy.id


  policy = jsonencode({

    Version = "2012-10-17"


    Statement = [

      {

        Effect = "Allow"


        Action = [

          "ssm:SendCommand",

          "ssm:GetCommandInvocation",

          "ssm:ListCommandInvocations",

          "ssm:ListCommands"

        ]


        Resource = "*"

      }

    ]

  })

}