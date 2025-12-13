# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # OIDC Provider for IRSA (only needed when using IRSA mode)
  enable_irsa = var.pod_authentication_mode == "irsa" ? true : false

  # Cluster addons
  cluster_addons = merge(
    {
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
        most_recent = true
      }
    },
    # Add Pod Identity agent addon when using Pod Identity mode
    var.pod_authentication_mode == "pod-identity" ? {
      eks-pod-identity-agent = {
        most_recent = true
      }
    } : {}
  )

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      name = "${var.cluster_name}-node-group"

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Launch template configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Node group IAM role
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      tags = {
        Name = "${var.cluster_name}-node"
      }
    }
  }

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  tags = {
    Name = var.cluster_name
  }
}

# ==============================================================================
# Backend Pod Authentication - Supports both IRSA and Pod Identity
# ==============================================================================

# IAM Role for IRSA mode (traditional method using OIDC)
resource "aws_iam_role" "backend_irsa" {
  count = var.pod_authentication_mode == "irsa" ? 1 : 0
  name  = "${var.cluster_name}-backend-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:todo-app:backend-sa"
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name               = "${var.cluster_name}-backend-irsa"
    AuthenticationMode = "irsa"
  }
}

# IAM Role for Pod Identity mode (newer, simpler method)
resource "aws_iam_role" "backend_pod_identity" {
  count = var.pod_authentication_mode == "pod-identity" ? 1 : 0
  name  = "${var.cluster_name}-backend-pod-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name               = "${var.cluster_name}-backend-pod-identity"
    AuthenticationMode = "pod-identity"
  }
}

# IAM Policy for DynamoDB access
resource "aws_iam_policy" "dynamodb_access" {
  name        = "${var.cluster_name}-dynamodb-access"
  description = "Policy for backend to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:DescribeTable"
        ]
        Resource = aws_dynamodb_table.todos.arn
      }
    ]
  })
}

# Attach DynamoDB policy to IRSA role
resource "aws_iam_role_policy_attachment" "backend_dynamodb_irsa" {
  count      = var.pod_authentication_mode == "irsa" ? 1 : 0
  role       = aws_iam_role.backend_irsa[0].name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# Attach DynamoDB policy to Pod Identity role
resource "aws_iam_role_policy_attachment" "backend_dynamodb_pod_identity" {
  count      = var.pod_authentication_mode == "pod-identity" ? 1 : 0
  role       = aws_iam_role.backend_pod_identity[0].name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# Pod Identity Association (only for Pod Identity mode)
resource "aws_eks_pod_identity_association" "backend" {
  count           = var.pod_authentication_mode == "pod-identity" ? 1 : 0
  cluster_name    = module.eks.cluster_name
  namespace       = "todo-app"
  service_account = "backend-sa"
  role_arn        = aws_iam_role.backend_pod_identity[0].arn

  tags = {
    Name = "${var.cluster_name}-backend-pod-identity-association"
  }
}
