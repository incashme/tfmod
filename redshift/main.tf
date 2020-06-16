data "aws_availability_zones" "available" {}


resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  snapshot_name = "${var.cluster_identifier}-redshift-db-snapshot-${random_string.suffix.result}"
}


resource "aws_redshift_subnet_group" "default" {
  name       = "${var.cluster_identifier}-redshift-db-group"
  subnet_ids = var.db_subnets

  tags = {
    name = "Redshift DB subnet group"
    environment = var.envt
  }
}
 
resource "aws_redshift_cluster" "arc" {

  cluster_identifier = var.cluster_identifier
  availability_zone      = data.aws_availability_zones.available.names[0]

  database_name           = var.dbname
  master_username         = var.dbuser
  master_password         = var.dbpwd

  cluster_subnet_group_name = aws_redshift_subnet_group.default.id 
  vpc_security_group_ids    = var.db_secgrps
  final_snapshot_identifier =  local.snapshot_name

  node_type          = var.node_type
  cluster_type       = var.cluster_type
}

output "redshift_endpoint" {
  value = aws_redshift_cluster.arc.endpoint
}

output "redshift_dns" {
  value = aws_redshift_cluster.arc.dns_name
}
output "redshift_port" {
  value = aws_redshift_cluster.arc.port
}

variable "cluster_identifier" {}
variable "dbname"             {}
variable "dbuser"             {}
variable "dbpwd"              {}

variable "node_type"          {}
variable "cluster_type"       {} 
variable "db_subnets"         { type=list(string) }  
variable "db_secgrps"         { type=list(string) }  
variable "envt"               {} 

