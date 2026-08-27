module "eks" {
  source = "../../modules/eks"

  cluster_name       = "${var.project_name}-${var.environment}-eks"
  kubernetes_version = "1.35"

  # Cost-optimized lab design:
  # public workers avoid a NAT Gateway.
  subnet_ids = module.vpc.public_subnet_ids

  # Restrict the public Kubernetes API to our admin IP.
  # Jenkins will later use the private cluster endpoint from inside the VPC.
  public_access_cidrs = [
    var.admin_cidr
  ]

  node_instance_types = ["t3.medium"]

  desired_size = 1
  min_size     = 0
  max_size     = 2
}

resource "aws_eks_access_entry" "jenkins_agent" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.devops_host["jenkins-agent"].arn

  type = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins_agent" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.devops_host["jenkins-agent"].arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"

  access_scope {
    type = "namespace"

    namespaces = [
      "i27-helpdesk-dev"
    ]
  }

  depends_on = [
    aws_eks_access_entry.jenkins_agent
  ]
}

data "aws_iam_policy_document" "jenkins_agent_eks" {
  statement {
    sid    = "DescribeHelpdeskEKS"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster"
    ]

    resources = [
      module.eks.cluster_arn
    ]
  }
}

resource "aws_iam_role_policy" "jenkins_agent_eks" {
  name = "${var.project_name}-${var.environment}-jenkins-agent-eks"
  role = aws_iam_role.devops_host["jenkins-agent"].id

  policy = data.aws_iam_policy_document.jenkins_agent_eks.json
}

# Allow EKS workloads to connect to RDS MySQL
resource "aws_vpc_security_group_ingress_rule" "rds_mysql_from_eks" {
  security_group_id            = module.rds.security_group_id
  referenced_security_group_id = module.eks.cluster_security_group_id

  from_port   = 3306
  to_port     = 3306
  ip_protocol = "tcp"

  description = "MySQL access from EKS cluster"
}
# Allow Jenkins Agent to communicate with the private EKS API endpoint
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jenkins_agent" {
  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = aws_security_group.jenkins_agent.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "HTTPS access to EKS API from Jenkins Agent"
}
