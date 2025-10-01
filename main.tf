# vpc 
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"  
  version = "5.4.0"  
  name = var.vpc_name
  cidr = var.vpc_cidr_block
  azs             = var.vpc_availability_zones
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets  
  database_subnets = var.vpc_database_subnets
  create_database_subnet_group = var.vpc_create_database_subnet_group
  create_database_subnet_route_table = var.vpc_create_database_subnet_route_table
  enable_nat_gateway = var.vpc_enable_nat_gateway 
  single_nat_gateway = var.vpc_single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = var.business_divsion
  vpc_tags = var.business_divsion

  public_subnet_tags = {
    Type = "Public Subnets"
    "kubernetes.io/role/elb" = 1    
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"        
  }
  private_subnet_tags = {
    Type = "private-subnets"
    "kubernetes.io/role/internal-elb" = 1    
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"    
  }

  database_subnet_tags = {
    Type = "database-subnets"
  }
  map_public_ip_on_launch = true
}
#seurity group 
module "public_bastion_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name = "public-bastion-sg"
  description = "Security Group with SSH port open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id = module.vpc.vpc_id
  ingress_rules = ["ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  tags = var.business_divsion
}

module "private_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name = "private-sg"
  description = "Security Group with HTTP & SSH port open for entire VPC Block (IPv4 CIDR), egress ports are all world open"
  vpc_id = module.vpc.vpc_id
  ingress_rules = ["ssh-tcp", "http-80-tcp"]
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  egress_rules = ["all-all"]
  tags = var.business_divsion
}

module "loadbalancer_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name = "loadbalancer-sg"
  description = "Security Group with HTTP open for entire Internet (IPv4 CIDR), egress ports are all world open"
  vpc_id = module.vpc.vpc_id
  ingress_rules = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  tags = var.business_divsion

  ingress_with_cidr_blocks = [
    {
      from_port   = 81
      to_port     = 81
      protocol    = 6
      description = "Allow Port 81 from internet"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}
# ec2 
module "ec2_public" {
  source        = "terraform-aws-modules/ec2-instance/aws"
  name          = "single-instance"
  instance_type = var.instance_type
  key_name      = "alb"
  monitoring    = true
  subnet_id     = module.vpc.public_subnets[0]
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  vpc_security_group_ids = [module.public_bastion_sg.security_group_id]
}

module "ec2_private" {
  depends_on = [ module.vpc ]
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.0.2"  
  name                   = "private"
  instance_type          = var.instance_type
  key_name               = "k8s"
  user_data              = file("${path.module}/app1-install.sh")   
  tags                   = var.business_divsion
  for_each               = toset(["0", "1"])
  subnet_id              =  element(module.vpc.private_subnets, tonumber(each.key))
  vpc_security_group_ids = [module.private_sg.security_group_id]
}

resource "aws_eip" "bastion_eip" {
  depends_on = [ module.ec2_public, module.vpc ]
  tags       = var.business_divsion
  instance   = module.ec2_public.id
  domain     = "vpc"  

}
#  alb
module "alb" {
  source                     = "terraform-aws-modules/alb/aws"
  version                    = "10.0.0"
  name                       = "alb"
  load_balancer_type         = "application"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  security_groups            = [module.loadbalancer_sg.security_group_id]
  enable_deletion_protection = false

  listeners = {
    my-http-listener = {
      port     = 80
      protocol = "HTTP"
      forward  = {
        target_group_key = "mytg1"
      }         
    }
  }

  target_groups = {     
   mytg1 = {
      create_attachment                 = false
      name_prefix                       = "mytg1-"
      protocol                          = "HTTP"
      port                              = 80
      target_type                       = "instance"
      deregistration_delay              = 10
      load_balancing_cross_zone_enabled = false
      protocol_version                  = "HTTP1"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/app1/index.html"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
      tags = var.business_divsion  
    } 
  } 
  tags = var.business_divsion 
}

resource "aws_lb_target_group_attachment" "mytg1" {
  for_each = {for k, v in module.ec2_private: k => v}
  target_group_arn = module.alb.target_groups["mytg1"].arn
  target_id        = each.value.id
  port             = 80
}

output "zz_ec2_private" {
  value = {for ec2_instance, ec2_instance_details in module.ec2_private: ec2_instance => ec2_instance_details}
}


