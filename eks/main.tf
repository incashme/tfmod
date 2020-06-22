data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.aws_eks.name
}

data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.aws_eks.name
}

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-ekscluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_cluster" "aws_eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = var.eks_subnets
  }

  tags = {
    environment = var.envt
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
  ]
}

resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-eksnode-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.aws_eks.name
  node_group_name = var.worker_group_name
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.eks_subnets
  instance_types  = [ var.instance_type ]  

  scaling_config {
    desired_size =  var.min_count
    max_size     =  var.max_count
    min_size     =  var.min_count
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

output "cluster_endpoint" {
  value = aws_eks_cluster.aws_eks.endpoint
}

output "cluster_ca" {
  value = data.aws_eks_cluster.cluster.certificate_authority
}

output "cluster_token" {
  value = data.aws_eks_cluster_auth.cluster.token
}


variable "cluster_name"        {}
// variable "eks_vpc_id"          {}
variable "worker_group_name"   {}
variable "instance_type"       {}

variable "min_count"           {}
variable "max_count"           {}

variable "eks_subnets"         { type=list(string) }
variable "eks_secgroups"       { type=list(string) }

variable "envt"                {}