data "aws_availability_zones" "available" {}


resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  snapshot_name = "${var.cluster_identifier}-db-snapshot-${random_string.suffix.result}"
  // snapshot_name = "loadtest-eks-${random_string.suffix.result}"
}


resource "aws_db_subnet_group" "default" {
  name       = "rds-db-group"
  subnet_ids = var.db_subnets

  tags = {
    Name = "${var.cluster_identifier} DB subnet group"
    environment = var.envt
  }
}

resource "aws_rds_cluster" "rdcluster" {
  cluster_identifier      = var.cluster_identifier
  engine                  = var.engine
  engine_version          = var.engine_version
  engine_mode             = "serverless"  
  availability_zones      = data.aws_availability_zones.available.names
  enable_http_endpoint    = true

  db_subnet_group_name    = aws_db_subnet_group.default.id
  vpc_security_group_ids  = var.db_secgrps

  database_name           = var.dbname
  master_username         = var.dbuser
  master_password         = var.dbpwd
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  
  final_snapshot_identifier = local.snapshot_name
  snapshot_identifier = var.base_snapshot


   scaling_configuration {
    auto_pause               = true
    max_capacity             = var.max_capacity
    min_capacity             = 2
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }

  tags = {
    environment = var.envt
  }
}

output "rds_endpoint" {
  value = aws_rds_cluster.rdcluster.endpoint
}

output "rds_reader_endpoint" {
  value = aws_rds_cluster.rdcluster.reader_endpoint
}


variable "cluster_identifier" {}
variable "inst_identifier"    {}
variable "engine"             {}
variable "engine_version"     {}

variable "dbname"             {}
variable "dbuser"             {}
variable "dbpwd"              {}

variable "base_snapshot"      {}
variable "max_capacity"       {}

variable "db_subnets"         { type=list(string) }  
variable "db_secgrps"         { type=list(string) }  

variable "envt"               {} 

