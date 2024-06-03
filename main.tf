data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "blog" {
  ami             = data.aws_ami.app_ami.id
  instance_type   = var.instance_type

  vpc_security_group_ids = [aws_security_group.blog.id]

  tags = {
    Name = "Learning Terraform"
  }
}
module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "var.environment.name"
  cidr = "${var.environment.network_prefix}.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]

    tags = {
    Terraform = "true"
    Environment = "var.environment.name"
  }
}

module "autoscaling" {
  source    = "HDE/autoscaling/aws"
  version   = "6.4.0"
  name      = "${var.environment.name}-blog"
  min_size  = var.asg_min_size
  max_size  = var.asg_max_size

  vpc_zone_identifier = module.blog_vpc.public_subnets
  target_group_arns   = module.blog_alb.target_group_arns

  security_groups     = [module.blog_secgrp.security_group_id]
  image_id            = data.aws_ami.app_ami.id
  instance_type       = var.instance_type
}

module "blog_alb" {
  source    = "terraform-aws-modules/alb/aws"
  version   = "~> 6.0"

  name      = "${var.environment.name}-my-alb"

  load_balancer_type = "application"

  vpc_id             = module.blog_vpc.vpc_id
  subnets            = module.blog_vpc.public_subnets
  security_groups    = [module.blog_secgrp.security_group_id]
 
  access_logs = {
    bucket = "my-alb-logs"
  }

  target_groups = [
    {
      name_prefix      = "${var.environment.name}-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "var.environment.name"
  }
}

module "blog_secgrp" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"
  
  vpc_id = module.blog_vpc.vpc_id
  name    = "${var.environment.name}-blog"
  
    ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}