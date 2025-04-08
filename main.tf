# -------------------
# VARIABLE DECLARATIONS
# -------------------

# Region in which to provision AWS resources
variable "aws_region" {}

# CIDR block for the VPC (e.g., "10.0.0.0/16")
variable "cidr_block" {}

# CIDR block for the subnet (e.g., "10.0.1.0/24")
variable "subnet_cidr_block" {}

# Name of the EC2 Key Pair used for SSH access
variable "key_pair_name" {}

# EC2 instance type (e.g., "t2.micro")
variable "instance_type" {}

# -------------------
# PROVIDER CONFIGURATION
# -------------------

# Configures the AWS provider with the specified region
provider "aws" {
  region = var.aws_region
}

# -------------------
# DATA SOURCES
# -------------------

# Fetches the most recent Amazon Linux 2 AMI (Amazon Machine Image)
data "aws_ami" "amazon_linux_2" {
  most_recent = true

  # Filters to only include AMIs with this naming pattern
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  # Filters to only include HVM virtualization type (required for EC2)
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Only get AMIs published by Amazon (owner ID)
  owners = ["137112412989"] # Amazon
}

# -------------------
# VPC & NETWORKING RESOURCES
# -------------------

# Create a custom Virtual Private Cloud (VPC)
resource "aws_vpc" "my-vpc" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "VPC-With-EC2"
  }
}

# Create a public subnet within the VPC
resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = var.subnet_cidr_block

  tags = {
    Name = "Public-Subnet"
  }
}

# Create an Internet Gateway and attach it to the VPC to enable internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "Internet-Gateway"
  }
}

# Add a default route to the internet via the internet gateway
resource "aws_default_route_table" "igw-route" {
  # Use the default route table associated with the VPC
  default_route_table_id = aws_vpc.my-vpc.default_route_table_id

  # Add a route for all IPv4 addresses (internet access)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "IGW-Route-Table"
  }
}

# -------------------
# SECURITY CONFIGURATION
# -------------------

# Create a security group for the EC2 instance
resource "aws_security_group" "sg-for-ec2" {
  name        = "SG-for-EC2"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  tags = {
    Name = "SG-for-EC2"
  }
}

# Allow inbound SSH (port 22) from anywhere (not recommended for production)
resource "aws_vpc_security_group_ingress_rule" "allow_inbound_ssh" {
  security_group_id = aws_security_group.sg-for-ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Allow inbound ICMP traffic (e.g., ping) from anywhere
resource "aws_vpc_security_group_ingress_rule" "allow_inbound_ICMP" {
  security_group_id = aws_security_group.sg-for-ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = -1        # ICMP types
  ip_protocol       = "icmp"    # Internet Control Message Protocol
  to_port           = -1
}

# -------------------
# EC2 INSTANCE
# -------------------

# Launch a single Amazon Linux 2 EC2 instance in the public subnet
resource "aws_instance" "public-ec2" {
  ami                         = data.aws_ami.amazon_linux_2.id  # Use latest Amazon Linux 2 AMI
  instance_type               = var.instance_type               # Instance type from variable
  associate_public_ip_address = true                            # Assign a public IP (for SSH/Internet)
  vpc_security_group_ids      = [aws_security_group.sg-for-ec2.id] # Attach the security group
  subnet_id                   = aws_subnet.public-subnet.id     # Launch in the public subnet
  key_name                    = var.key_pair_name               # Required for SSH access

  tags = {
    Name = "Public-EC2"
  }
}
