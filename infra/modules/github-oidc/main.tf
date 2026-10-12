# Lets GitHub Actions workflows get SHORT-LIVED AWS credentials without any stored access keys.
#
# Flow: workflow requests an OIDC token from GitHub -> sends it to AWS STS ->
#       STS checks it against this role's trust policy -> returns temporary credentials (1 hour).

# An account can have only ONE OIDC provider per URL, and this account already has one
# (created before this project). We look it up instead of creating it, so this stack never
# owns or destroys a provider that other projects rely on.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ---------- Role: build and push container images ----------

data "aws_iam_policy_document" "ecr_push_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    # The token must have been issued for AWS...
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # ...and must come from exactly the repo/branch/environment you listed.
    # This condition is THE security control. Without it, any GitHub repo on earth could assume the role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.ecr_push_subjects
    }
  }
}

resource "aws_iam_role" "ecr_push" {
  name               = "${var.name}-ci-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.ecr_push_trust.json
}

data "aws_iam_policy_document" "ecr_push" {
  # docker login to ECR. This action does not support resource-level scoping, so "*" is required.
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push layers and manifests, to our repositories only.
  statement {
    sid = "PushToOurRepositoriesOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}