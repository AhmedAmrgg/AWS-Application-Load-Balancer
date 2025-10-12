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
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Allow HTTP on port 8080"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]
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

module "ec2_private_app1" {
  depends_on = [ module.vpc ]
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.0.2"  
  name                   = "app1"
  instance_type          = var.instance_type
  key_name               = "k8s"
  user_data              = file("${path.module}/app1-install.sh")   
  tags                   = var.business_divsion
  for_each               = toset(["0", "1"])
  subnet_id              =  element(module.vpc.private_subnets, tonumber(each.key))
  vpc_security_group_ids = [module.private_sg.security_group_id]
}


module "ec2_private_app2" {
  depends_on = [ module.vpc ] 
  source  = "terraform-aws-modules/ec2-instance/aws"
  name                   = "$app2"
  instance_type          = var.instance_type
  key_name               = var.instance_keypair
  user_data = file("${path.module}/app2-install.sh")
  tags = var.business_divsion
  for_each = toset(["0", "1"])
  subnet_id =  element(module.vpc.private_subnets, tonumber(each.key))
  vpc_security_group_ids = [module.private_sg.security_group_id]
}

module "ec2_private_app3" {
  depends_on = [ module.vpc ] 
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.0.2"  
  name                   = "app3"
  instance_type          = var.instance_type
  key_name               = var.instance_keypair
  user_data =  templatefile("app3-ums-install.tmpl",{rds_db_endpoint = module.rdsdb.db_instance_address})    
  tags = var.business_divsion
  for_each = toset(["0", "1"])
  subnet_id =  element(module.vpc.private_subnets, tonumber(each.key))
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
    my-https-listener = {
      port                        = 80
      protocol                    = "HTTP"    
      fixed_response =  {
        content_type = "text/plain"
        message_body = "Fixed Static message - for Root Context"
        status_code  = "200"
      }

      rules = {
        myapp1-rule = {
          priority = 10
          actions = [{
            weighted_forward = {
            target_groups = [
              {
                target_group_key = "mytg1"
                weight           = 1
              }
            ]
            stickiness = {
              enabled  = true
              duration = 3600
            }
          }}]
          conditions = [{
            path_pattern = {
              values = ["/app1*"]
            }
          }]
        }

        myapp2-rule = {
          priority = 20          
          actions = [{
            weighted_forward = {
            target_groups = [
              {
                target_group_key = "mytg2"
                weight           = 1
              }
            ]
            stickiness = {
              enabled  = true
              duration = 3600
            }
          }}]
          conditions = [{
            path_pattern = {
              values = ["/app2*"]
            }
          }]
        }

        myapp3-rule = {
          priority = 30          
          actions = [{
            weighted_forward = {
            target_groups = [
              {
                target_group_key = "mytg3"
                weight           = 1
              }
            ]
            stickiness = {
              enabled  = true
              duration = 3600
            }
          }}]
          conditions = [{
            path_pattern = {
              values = ["/login"]
            }
          }]
        }
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
   
   mytg2 = {
      create_attachment                 = false
      name_prefix                       = "mytg2-"
      protocol                          = "HTTP"
      port                              = 80
      target_type                       = "instance"
      deregistration_delay              = 10
      load_balancing_cross_zone_enabled = false
      protocol_version                  = "HTTP1"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/app2/index.html"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
      tags = var.business_divsion  
    } 

   mytg3 = {
      create_attachment                 = false
      name_prefix                       = "mytg3-"
      protocol                          = "HTTP"
      port                              = 8080
      target_type                       = "instance"
      deregistration_delay              = 10
      load_balancing_cross_zone_enabled = false
      protocol_version                  = "HTTP1"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/login"
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
}



resource "aws_lb_target_group_attachment" "mytg1" {
  for_each = {for k, v in module.ec2_private_app1: k => v}
  target_group_arn = module.alb.target_groups["mytg1"].arn
  target_id        = each.value.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "mytg2" {
  for_each = {for k,v in module.ec2_private_app2: k => v}
  target_group_arn = module.alb.target_groups["mytg2"].arn
  target_id        = each.value.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "mytg3" {
  for_each = {for k,v in module.ec2_private_app3: k => v}
  target_group_arn = module.alb.target_groups["mytg3"].arn
  target_id        = each.value.id
  port             = 8080
}

#rds 
module "rdsdb" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.13.0"
  identifier = var.db_instance_identifier
  db_name     = var.db_name  
  username = var.db_username
  password = var.db_password
  manage_master_user_password = false 
  port     = 3306


  multi_az               = true
  create_db_subnet_group = true 
  subnet_ids             = module.vpc.database_subnets
  vpc_security_group_ids = [module.rdsdb_sg.security_group_id]

  
  engine               = "mysql"
  engine_version       = "8.4.6"
  family               = "mysql8.4" 
  major_engine_version = "8.4"      
  instance_class       = "db.t3.large"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = false


  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["general"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_role_arn	   = "arn:aws:iam::313616258649:role/rds-monitoring-role"
  monitoring_interval                   = 60

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  tags = var.business_divsion
  db_instance_tags = {
    "Sensitive" = "high"
  }
  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
  db_subnet_group_tags = {
    "Sensitive" = "high"
  }
}

module "rdsdb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"  

  name        = "rdsdb-sg"
  description = "Access to MySQL DB for entire VPC CIDR Block"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]
  
  egress_rules = ["all-all"]  
  tags = var.business_divsion
}



