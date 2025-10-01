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

variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as a prefix in names of related resources."
  type        = string
  default     = "eksdemo"
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

