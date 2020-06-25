provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.11"
}

data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "test-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = var.cluster_name
  subnets      = var.eks_subnets
  cluster_enabled_log_types = ["api","controllerManager","scheduler","authenticator","audit"]
  enable_irsa  = true 
  iam_path = "/tf/"
  
  tags = {
    Environment = var.envt
  }

  vpc_id = var.eks_vpc_id
  worker_groups = [
    {
      name                 = var.worker_group_name
      instance_type        = var.instance_type
      asg_desired_capacity = var.desired_count
      asg_max_size     = var.max_count
      asg_min_size     = var.min_count
      autoscaling_enabled   = true
      public_ip        = true
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "propagate_at_launch" = "true"
          "value"               = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
          "propagate_at_launch" = "true"
          "value"               = "true"
        }
      ]
    }
  ]
  map_roles    = var.map_roles
  map_users    = var.map_users
}

resource "local_file" "kubec" {
    content     = module.eks.kubeconfig
    filename = "/tmp/kubc.yaml"
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}
output "worker_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.worker_security_group_id
}


output "kubectl_config" {
  description = "kubectl config as generated by the module."
  value       = module.eks.kubeconfig
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks.config_map_aws_auth
}

output "node_groups" {
  description = "Outputs from node groups"
  value       = module.eks.node_groups
}

output "cluster_token" {
  value = data.aws_eks_cluster_auth.cluster.token
}

output "cluster_ca" {
  value = data.aws_eks_cluster.cluster.certificate_authority
}

output "kubefile"{
  value = local_file.kubec.filename
}
output "cluster_name" {
  value = var.cluster_name 
}

variable "cluster_name"        {}
variable "eks_vpc_id"          {}
variable "worker_group_name"   {}
variable "instance_type"       {}

variable "min_count"           {}
variable "max_count"           {}
variable "desired_count"       {}

variable "eks_subnets"         { type=list(string) }
variable "eks_secgroups"       { type=list(string) }

variable "envt"                {}

variable "map_roles"             { 
    type= list(object({
        rolearn  = string
        username = string
        groups   = list(string)
    }))
} 

variable "map_users"             { 
    type= list(object({
        userarn  = string
        username = string
        groups   = list(string)
    }))
} 