data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = var.vpc_name
  cidr                 = var.cidr
  azs                  = data.aws_availability_zones.available.names
  
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  
  
  enable_nat_gateway   = var.enable_nat 
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_s3_endpoint   = true
  enable_dynamodb_endpoint = true

  tags = {
    "kubernetes.io/cluster/${var.kcluster_name}" = "shared"
    "environment" = var.envt
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.kcluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.kcluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}



resource "aws_security_group" "ssh_access" {
  name_prefix = "ssh_access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      "10.0.0.0/8"
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_jump_access" {
  name_prefix = "db_jump_access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    cidr_blocks = [
      var.jumpbox
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "redshift_jump_access" {
  name_prefix = "redshift_jump_access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 5439
    to_port   = 5439
    protocol  = "tcp"
    cidr_blocks = [
      var.jumpbox
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "redis_jump_access" {
  name_prefix = "redis_jump_access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"
    cidr_blocks = [
      var.jumpbox
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



output "vpc_id"                { value = module.vpc.vpc_id }
output "sg_ssh_id"             { value = aws_security_group.ssh_access.id }
output "sg_dbjump_id"          { value = aws_security_group.db_jump_access.id }
output "sg_redshift_jump_id"   { value = aws_security_group.redshift_jump_access.id }
output "sg_redis_jump_id"      { value = aws_security_group.redis_jump_access.id }

output "public_subnets"      { value = module.vpc.public_subnets }
output "private_subnets"     { value = module.vpc.private_subnets }
// output "kcluster_name"       { value = var.kcluster_name }


variable "vpc_name"        {}
variable "cidr"            {}
variable "public_subnets"  { type=list(string) }
variable "private_subnets" { type=list(string) }
variable "enable_nat"      { type=bool }
variable "kcluster_name"   {}
variable "envt"            {}
variable "jumpbox"         {}
