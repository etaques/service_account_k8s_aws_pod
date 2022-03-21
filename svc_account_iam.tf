data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "eks_pods" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:observability:logs-s3"]
    }

    principals {
      identifiers = [data.aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
  }
}
resource "aws_iam_policy" "eks_pods_s3" {
  name = "policy-dev-logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:*"]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.environment}-orb-logs",
          "arn:aws:s3:::${var.environment}-orb-logs/*"
        ]
      },
    ]
  })
}

# create a role that can be attached to pods.
resource "aws_iam_role" "eks_pods" {
  assume_role_policy = data.aws_iam_policy_document.eks_pods.json
  name               = "eks-pods-iam-loki-logs"

  depends_on = [module.eks]
}

resource "aws_iam_role_policy_attachment" "aws_pods" {
  role       = aws_iam_role.eks_pods.name
  policy_arn = aws_iam_policy.eks_pods_s3.arn

  depends_on = [aws_iam_role.eks_pods]
}
