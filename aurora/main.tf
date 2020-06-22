
module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "2.19.0"

  name                            = var.cluster_identifier
  engine                          = var.engine
  engine_version                  = var.engine_version
  subnets                         = var.db_subnets
  vpc_id                          = var.vpc_id
  replica_count                   = var.min_node
  replica_scale_enabled           = true
  replica_scale_min               = var.min_node
  replica_scale_max               = var.max_node
  monitoring_interval             = 60
  instance_type                   = var.instance_class
  snapshot_identifier             = var.base_snapshot

  apply_immediately               = true
  performance_insights_enabled    = true 

  database_name           = var.dbname
  username                = var.dbuser
  password                = var.dbpwd

  db_parameter_group_name         = aws_db_parameter_group.aurora_db_postgres96_parameter_group.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_cluster_postgres96_parameter_group.id
//   enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
//   skip_final_snapshot             = true

}

resource "aws_db_parameter_group" "aurora_db_postgres96_parameter_group" {
  name        = "test-aurora-db-postgres10-parameter-group"
  family      = "aurora-postgresql10"
  description = "test-aurora-db-postgres10-parameter-group"
}

resource "aws_rds_cluster_parameter_group" "aurora_cluster_postgres96_parameter_group" {
  name        = "test-aurora-postgres10-cluster-parameter-group"
  family      = "aurora-postgresql10"
  description = "test-aurora-postgres10-cluster-parameter-group"
}

############################
# Example of security group
############################
resource "aws_security_group" "app_servers" {
  name        = "app-servers"
  description = "For application servers"
  vpc_id      = var.vpc_id
}

// resource "aws_security_group_rule" "allow_access" {
//   type                     = "ingress"
//   from_port                = module.aurora.this_rds_cluster_port
//   to_port                  = module.aurora.this_rds_cluster_port
//   protocol                 = "tcp"
//   source_security_group_id = aws_security_group.app_servers.id
//   security_group_id        = module.aurora.this_security_group_id
// }


output "rds_cluster_endpoint" {
  description = "The cluster endpoint"
  value       = module.aurora.this_rds_cluster_endpoint
}

output "rds_cluster_reader_endpoint" {
  description = "The cluster reader endpoint"
  value       = module.aurora.this_rds_cluster_reader_endpoint
}


variable "cluster_identifier" {}
variable "engine"             {}
variable "engine_version"     {}

variable "dbname"             {}
variable "dbuser"             {}
variable "dbpwd"              {}

variable "base_snapshot"      {}
variable "instance_class"     {} 
variable "max_node"           {}
variable "min_node"           {}

variable "db_subnets"         { type=list(string) }  
variable "vpc_id"             {}
variable "envt"               {} 

// variable "db_secgrps"         { type=list(string) }  
// variable "instance_count"     {}
