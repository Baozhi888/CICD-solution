# =============================================================================
# Terraform AWS 基础设施模板
# =============================================================================
# 完整的 AWS 基础设施配置
#
# 用法:
#   terraform init
#   terraform plan -var-file="env/production.tfvars"
#   terraform apply -var-file="env/production.tfvars"
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # 远程状态存储 (推荐)
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# =============================================================================
# 变量定义
# =============================================================================

variable "project_name" {
  description = "项目名称"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "环境 (dev/staging/production)"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS 区域"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR 块"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "可用区列表"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes 版本"
  type        = string
  default     = "1.28"
}

variable "node_instance_types" {
  description = "EKS 节点实例类型"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "node_desired_size" {
  description = "期望节点数"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "最小节点数"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "最大节点数"
  type        = number
  default     = 10
}

variable "db_instance_class" {
  description = "RDS 实例类型"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "RDS 存储大小 (GB)"
  type        = number
  default     = 20
}

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Provider 配置
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "terraform"
      },
      var.tags
    )
  }
}

# =============================================================================
# 数据源
# =============================================================================

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# VPC 网络
# =============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + 4)]

  # NAT Gateway
  enable_nat_gateway     = true
  single_nat_gateway     = var.environment != "production"
  one_nat_gateway_per_az = var.environment == "production"

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  # EKS 所需标签
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
    "kubernetes.io/role/elb"                                        = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
    "kubernetes.io/role/internal-elb"                               = 1
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# =============================================================================
# EKS 集群
# =============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # 集群端点访问
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # 加密
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # 节点组
  eks_managed_node_groups = {
    main = {
      name           = "${var.project_name}-${var.environment}-main"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # 使用 Spot 实例节省成本 (非生产环境)
      capacity_type = var.environment == "production" ? "ON_DEMAND" : "SPOT"

      # 磁盘配置
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # 节点标签
      labels = {
        Environment = var.environment
      }

      # 污点 (可选)
      # taints = []
    }
  }

  # OIDC Provider for IAM Roles for Service Accounts
  enable_irsa = true

  # 集群插件
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks"
  }
}

# EBS CSI Driver IAM Role
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.project_name}-${var.environment}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# KMS Key for EKS
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-key"
  }
}

# =============================================================================
# RDS PostgreSQL
# =============================================================================

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-${var.environment}-db"

  engine               = "postgres"
  engine_version       = "15.4"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 5

  db_name  = replace(var.project_name, "-", "_")
  username = var.project_name
  port     = 5432

  # 高可用 (生产环境)
  multi_az = var.environment == "production"

  # 子网组
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.security_group_rds.security_group_id]

  # 备份
  backup_retention_period = var.environment == "production" ? 30 : 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # 加密
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # 性能监控
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # 删除保护 (生产环境)
  deletion_protection = var.environment == "production"

  tags = {
    Name = "${var.project_name}-${var.environment}-rds"
  }
}

# RDS 安全组
module "security_group_rds" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "RDS security group"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      source_security_group_id = module.eks.node_security_group_id
    },
  ]
}

# KMS Key for RDS
resource "aws_kms_key" "rds" {
  description             = "RDS Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-key"
  }
}

# =============================================================================
# ElastiCache Redis
# =============================================================================

module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  cluster_id           = "${var.project_name}-${var.environment}"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.environment == "production" ? "cache.r6g.large" : "cache.t3.micro"
  num_cache_nodes      = var.environment == "production" ? 2 : 1
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [module.security_group_redis.security_group_id]

  # 加密
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-redis"
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis"
  subnet_ids = module.vpc.private_subnets
}

# Redis 安全组
module "security_group_redis" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Redis security group"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 6379
      to_port                  = 6379
      protocol                 = "tcp"
      source_security_group_id = module.eks.node_security_group_id
    },
  ]
}

# =============================================================================
# 输出
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS 集群名称"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS 集群端点"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS 端点"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis 端点"
  value       = module.elasticache.cluster_cache_nodes[0].address
  sensitive   = true
}

output "kubeconfig_command" {
  description = "配置 kubectl 的命令"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
