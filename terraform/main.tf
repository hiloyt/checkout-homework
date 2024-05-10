module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway           = true
  single_nat_gateway           = true
  enable_dns_hostnames         = true
  manage_default_network_acl   = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

resource "aws_iam_policy" "additional" {
  name = "${local.name}-additional"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "20.10.0"

  cluster_name                   = "${local.name}-eks-fg"
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    kube-proxy = {}
    vpc-cni    = {}
    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  fargate_profile_defaults = {
    iam_role_additional_policies = {
      additional = aws_iam_policy.additional.arn
    }
  }

  fargate_profiles = merge(
    {
      checkout = {
        name = "checkout"
        selectors = [
          {
            namespace = "app-*"
            labels = {
              app = "checkout"
            }
          }
        ]

        subnet_ids = [module.vpc.private_subnets[1]]

        tags = {
          Owner = "secondary"
        }

        timeouts = {
          create = "20m"
          delete = "20m"
        }
      }
    },
    {
      devops = {
        name = "devops"
        selectors = [
          {
            namespace = "devops-*"
          }
        ]

        subnet_ids = [module.vpc.private_subnets[1]]

        tags = {
          Owner = "secondary"
        }

        timeouts = {
          create = "20m"
          delete = "20m"
        }
      }
    },
    {
    kube-system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
    }
  )

  tags = local.tags
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "2.2.1"

  repository_name = local.name

  repository_read_write_access_arns = [data.aws_caller_identity.current.arn]
  create_lifecycle_policy           = false
  attach_repository_policy          = false
  tags                              = local.tags
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role_policy.json
  name               = "aws-load-balancer-controller"
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  policy = file("./AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "devops-monitoring"
  create_namespace = true
  version    = local.metrics_server_verion
  wait = true
  timeout = 1200  

  values = [
    "${file("ms-values.yaml")}"
  ]

  depends_on = [
    module.eks
  ]
}

resource "helm_release" "aws-load-balancer-controller" {
  name = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "devops-ingress"
  create_namespace = true
  version    = local.alb_chart_verion
  wait = true
  timeout = 1200 

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  set {
    name  = "region"
    value = local.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    module.eks
  ]
}