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
  name       = "${var.cluster_identifier}-rds-db-group"
  subnet_ids = var.db_subnets

  tags = {
    name = "DB subnet group"
    environment = var.envt
  }
}

resource "aws_rds_cluster" "rdcluster" {
  // cluster_identifier      = var.cluster_identifier
  engine                  = var.engine
  engine_version          = var.engine_version

  // availability_zones      = data.aws_availability_zones.available.names
  availability_zones      = ["ap-south-1a","ap-south-1b","ap-south-1c"]
  
  db_subnet_group_name    = aws_db_subnet_group.default.id
  vpc_security_group_ids  = var.db_secgrps

  database_name           = var.dbname
  master_username         = var.dbuser
  master_password         = var.dbpwd
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  // skip_final_snapshot       = true
  final_snapshot_identifier = local.snapshot_name

  snapshot_identifier = var.base_snapshot

  apply_immediately = true
  storage_encrypted = false

  tags = {
    environment = var.envt
  }
}

resource "aws_rds_cluster_instance" "rdsinst" {
  count               = var.instance_count
  // identifier          = "${var.inst_identifier}-${count.index}"

  cluster_identifier  = aws_rds_cluster.rdcluster.id
  engine              = aws_rds_cluster.rdcluster.engine
  engine_version      = aws_rds_cluster.rdcluster.engine_version

  // availability_zone  = "ap-south-1a"
 //  publicly_accessible = true

  apply_immediately   = true
  performance_insights_enabled = true

  instance_class     = var.instance_class
   
  tags = {
    environment = var.envt
  }  
}


output "rds_endpoint" {
  value = aws_rds_cluster_instance.rdsinst.*.endpoint
}

output "rds_endpoint_iswriter" {
  value = aws_rds_cluster_instance.rdsinst.*.writer
}


variable "cluster_identifier" {}
variable "inst_identifier"    {}
variable "engine"             {}
variable "engine_version"     {}

variable "dbname"             {}
variable "dbuser"             {}
variable "dbpwd"              {}

variable "base_snapshot"      {}
variable "instance_count"     {}
variable "instance_class"     {} 

variable "db_subnets"         { type=list(string) }  
variable "db_secgrps"         { type=list(string) }  

variable "envt"               {} 

