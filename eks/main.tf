data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = var.cluster_name
  subnets      = var.eks_subnets

  tags = {
    Environment = var.envt
  }

  vpc_id = var.eks_vpc_id

  worker_groups = [
    {
      name                          = var.worker_group_name
      instance_type                 = var.instance_type
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = var.min_count
      asg_max_size                  = var.max_count
      asg_min_size                  = var.min_count
      additional_security_group_ids = var.eks_secgroups
    },
  ]
}


output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "kubectl_config" {
  description = "kubectl config as generated by the module."
  value       = module.eks.kubeconfig
}

output "cluster_ca" {
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_token" {
  value = data.aws_eks_cluster_auth.cluster.token
}


variable "cluster_name"        {}
variable "eks_vpc_id"          {}
variable "worker_group_name"   {}
variable "instance_type"       {}

variable "min_count"           {}
variable "max_count"           {}

variable "eks_subnets"         { type=list(string) }
variable "eks_secgroups"       { type=list(string) }

variable "envt"                {}