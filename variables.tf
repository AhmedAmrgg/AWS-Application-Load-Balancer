# variable vpc 
variable "vpc_name" {
  description = "VPC Name"
  type = string 
}

variable "vpc_cidr_block" {
  description = "VPC CIDR Block"
  type = string 
}

variable "vpc_availability_zones" {
  description = "VPC Availability Zones"
  type = list(string)
}

variable "vpc_public_subnets" {
  description = "VPC Public Subnets"
  type = list(string)
}

variable "vpc_private_subnets" {
  description = "VPC Private Subnets"
  type = list(string)
}

variable "vpc_database_subnets" {
  description = "VPC Database Subnets"
  type = list(string)
}

variable "vpc_create_database_subnet_group" {
  description = "VPC Create Database Subnet Group"
  type = bool 
}

variable "vpc_create_database_subnet_route_table" {
  description = "VPC Create Database Subnet Route Table"
  type = bool   
}
   
variable "vpc_enable_nat_gateway" {
  description = "Enable NAT Gateways for Private Subnets Outbound Communication"
  type = bool
  default = true  
}

variable "vpc_single_nat_gateway" {
  description = "Enable only single NAT Gateway in one Availability Zone to save costs during our demos"
  type = bool
  default = true
}

variable "business_divsion" {
  description = "Common tags for resources"
  type        = map(string)
  default = {
    Owner       = "SAP"
    Environment = "Dev"
    Project     = "EKS"
  }
}

# variable ec2 
variable "instance_type" {
  description = "EC2 Instance Type"
  type = string
  default = "t3.micro"  
}

variable "instance_keypair" {
  description = "AWS EC2 Key pair that need to be associated with EC2 Instance"
  type = string
  default = "k8s"
}

variable "private_instance_count" {
  description = "AWS EC2 Private Instances Count"
  type = number
  default = 1  
}

variable "aws_region" {
  description = "Region in which AWS Resources to be created"
  type = string
  default = "us-east-1"  
}

variable "environment" {
  description = "Environment Variable used as a prefix"
  type = string
  default = "dev"
}

