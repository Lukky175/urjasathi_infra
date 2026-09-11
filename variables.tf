variable "aws_region" {

  description = "AWS region"

  type = string

  default = "ap-south-1"

}


variable "instance_type" {

  description = "EC2 instance type"

  type = string

  default = "t3.medium"

}


variable "project_name" {

  description = "Project name"

  type = string

  default = "urjasathi"

}


variable "app_repository" {

  description = "UrjaSathi application GitHub repository in owner/repository format"

  type = string

}