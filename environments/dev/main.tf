terraform {
  required_version = ">= 1.3"

  # Configure S3 backend for remote state
  # Update the bucket name to your actual S3 bucket
  backend "s3" {
    bucket         = "eks-terraform-state-akshay-2"  # TODO: Update this
    key            = "eks/dev/terraform.tfstate"
    region         = "us-east-1"  # Update based on your actual region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"  # Optional: for state locking
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
      Project     = "eks-graviton-cluster"
      Owner       = "devops-team"
    }
  }
}

# Data source for EKS cluster auth
# data "aws_eks_cluster" "cluster" {
#   name = module.eks.cluster_name

#   depends_on = [module.eks]
# }

# data "aws_eks_cluster_auth" "cluster" {
#   name = module.eks.cluster_name

#   depends_on = [module.eks]
# }

# Helm Provider Configuration
# provider "helm" {
#   kubernetes {
#     host                   = data.aws_eks_cluster.cluster.endpoint
#     cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
#     token                  = data.aws_eks_cluster_auth.cluster.token
#   }
# }

# Kubectl Provider Configuration
# provider "kubectl" {
#   host                   = data.aws_eks_cluster.cluster.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.cluster.token
#   load_config_file       = false
# }

# Networking Module - Fetches existing VPC and subnets
module "networking" {
  source = "../../modules/networking"

  vpc_name_tag                = var.vpc_name_tag
  office_security_group_name  = var.office_security_group_name
  ssh_key_name                = var.ssh_key_name
}

# EKS Module - Creates the EKS cluster with Graviton nodes
module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  office_security_group_id = module.networking.office_security_group_id
  ssh_key_name             = var.ssh_key_name

  enable_public_access = var.enable_public_access
  environment          = "dev"

  karpenter_node_instance_types = var.karpenter_node_instance_types
  karpenter_node_min_size       = var.karpenter_node_min_size
  karpenter_node_max_size       = var.karpenter_node_max_size
  karpenter_node_desired_size   = var.karpenter_node_desired_size

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Karpenter Module - Installs and configures Karpenter
module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name                   = module.eks.cluster_name
  cluster_endpoint               = module.eks.cluster_endpoint
  karpenter_version              = var.karpenter_version
  karpenter_controller_role_arn  = module.eks.karpenter_controller_role_arn
  karpenter_node_role_name       = split("/", module.eks.karpenter_node_role_arn)[1]
  interruption_queue_name        = module.eks.karpenter_interruption_queue_name
  private_subnet_ids             = module.networking.private_subnet_ids
  node_security_group_id         = module.eks.node_security_group_id

  capacity_types    = var.karpenter_capacity_types
  instance_families = var.karpenter_instance_families
  cpu_limit         = var.karpenter_cpu_limit
  memory_limit      = var.memory_limit

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
