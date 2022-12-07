## To get Own ip
data "http" "laptop_outbound_ip" {
  url = "https://ifconfig.me/ip"
}

#======================
## Cloud 9 Environment
#======================
resource "aws_cloud9_environment_ec2" "TestCloud9" {
  name = "Cloud9EC2Bastion-Terraform"
  instance_type = var.instance_type
  automatic_stop_time_minutes = 30
  connection_type = "CONNECT_SSH"
  image_id = "resolve:ssm:/aws/service/cloud9/amis/amazonlinux-2-x86_64"
  subnet_id = var.subnet_id
  description = "Cloud9 EC2 environment - Terraform"
  owner_arn = var.owner_arn
  tags      = {
    Terraform = "true"
    Project = "Demo"
  }
}

#===================================================
# Below resource is to create public and private key
#===================================================
resource "tls_private_key" "DemoPrivateKey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.aws_public_key_name}"
  public_key = tls_private_key.DemoPrivateKey.public_key_openssh
}

#===============================
# Security Group for Cloud9 Env
#===============================
data "aws_security_group" "cloud9_secgroup" {
    filter {
    name = "tag:aws:cloud9:environment"
        values = [
          aws_cloud9_environment_ec2.TestCloud9.id
        ]
    }
}
resource "aws_security_group_rule" "tcp_8080" {
    type              = "ingress"
    from_port         = 8080
    to_port           = 8080
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    ipv6_cidr_blocks  = ["::/0"]
    security_group_id = data.aws_security_group.cloud9_secgroup.id
}


#============================
# Get the later Amazon2 AMI
#============================
data "aws_ami" "linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

#===============================
# Create EC2 with docker service
#===============================
resource "aws_instance" "prometheus_Server" {
  ami           = data.aws_ami.linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.generated_key.key_name
  subnet_id     = var.subnet_id
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile_Prometheus.name
  root_block_device {
    volume_size = 8
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
  EOF

  vpc_security_group_ids = [aws_security_group.Prometheus_sg.id]
    tags = {
    Name = "Prometheus_Server"
    project = "Prometheus-Server"
  }
  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}

#===========================================
# EC2 Role and profile for Prometheus Server
#===========================================
resource "aws_iam_role" "ec2_role_Prometheus" {
  name = "Prometheus_EC2Role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    project = "EC2Role-Prometheus"
  }
}

resource "aws_iam_instance_profile" "ec2_profile_Prometheus" {
  name = "ec2_profile_Prometheus"
  role = aws_iam_role.ec2_role_Prometheus.name
}


#=======================
# Get the policy by name
#=======================
data "aws_iam_policy" "_AmazonPrometheusRemoteWriteAccess" {
  name = "AmazonPrometheusRemoteWriteAccess"
}

#==============================
# Attach the policy to the role
#===============================
resource "aws_iam_role_policy_attachment" "attach-AmazonPrometheusRemoteWriteAccess" {
  role       = aws_iam_role.ec2_role_Prometheus.name
  policy_arn = data.aws_iam_policy._AmazonPrometheusRemoteWriteAccess.arn
}


#======================================
# Security Group for Prometheus Server
#======================================
resource "aws_security_group" "Prometheus_sg" {
  name        = "Security Groups for Prometheus Server"
  description = "Allow SSH access to Kafka Client from Cloud9 and outbound internet access"
  vpc_id      = var.vpc_id
  tags = {
    Name = "Prometheus_sg_terraform"
  }
}

#---------------------------------
#Outbound for Prometheus Server SG
#---------------------------------
resource "aws_security_group_rule" "internetPrometheusSG" {
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.Prometheus_sg.id
}

#---------------------------------
#Inbound for Prometheus Server SG
#---------------------------------
resource "aws_security_group_rule" "PrometheusUIAccess" {
  protocol          = "tcp"
  from_port         = 9090
  to_port           = 9090
  type              = "ingress"
  cidr_blocks       = ["${chomp(data.http.laptop_outbound_ip.response_body)}/32"]
  security_group_id = aws_security_group.Prometheus_sg.id
}


#--------------------------------------------------------
#Inbound for Prometheus Server SG - SSH from Bastion Host
#--------------------------------------------------------
resource "aws_security_group_rule" "Prometheus_SSH" {
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  type              = "ingress"
  #cidr_blocks       = ["${chomp(data.http.laptop_outbound_ip.response_body)}/32"]
  source_security_group_id = data.aws_security_group.cloud9_secgroup.id
  security_group_id = aws_security_group.Prometheus_sg.id
}