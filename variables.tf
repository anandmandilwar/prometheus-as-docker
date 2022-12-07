#NV regions
variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-east-1"
}

variable "subnet_id" {
  description = "AWS subnet to launch EC2."
}

variable "instance_type" {
  description = "AWS Instance type"
  default     = "t3.medium"
}

variable "aws_public_key_name" {
  default = "prometheus_aws_rsa"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "owner_arn" {
  description = "ARN of the environment owner"
}
