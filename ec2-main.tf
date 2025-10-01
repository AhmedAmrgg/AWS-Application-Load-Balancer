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


 