
resource "aws_elasticache_subnet_group" "redis_subnet" {
  name       = "redis-subnet"
  subnet_ids = var.redis_subnets


  tags = {
    name = "Redis subnet group"
    environment = var.envt
  }

}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = var.cluster_id
  engine               = "redis"
  node_type            = var.node_type
  num_cache_nodes      = var.num_nodes

  parameter_group_name = "default.redis5.0"
  engine_version       = var.engine_version
  port                 = 6379
  apply_immediately    = true

  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet.id
  security_group_ids   = var.redis_secgrps


}

variable "cluster_id"            {} 
variable "node_type"             {} 
variable "num_nodes"             {} 
variable "engine_version"        {} 

variable "redis_subnets"         { type=list(string) }  
variable "redis_secgrps"         { type=list(string) }  
variable "envt"                  {} 

