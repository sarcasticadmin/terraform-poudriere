data "aws_iam_policy_document" "ec2_assumerole" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "poudriere" {
  statement {
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]

    resources = ["arn:aws:s3:::*"]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = ["arn:aws:s3:::${var.pkg_s3_bucket}"]
  }

  statement {
    actions = [
      "s3:*",
    ]

    resources = ["arn:aws:s3:::${var.pkg_s3_bucket}", "arn:aws:s3:::${var.pkg_s3_bucket}/*"]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = ["arn:aws:s3:::${var.signing_s3_key}"]
  }

  statement {
    actions = [
      "ec2:Describe*",
    ]

    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "autoscaling:SetDesiredCapacity",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/role"

      values = [
        "poudriere",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_instance_profile" "poudriere" {
  name_prefix = "poudriere"
  role        = "${aws_iam_role.poudriere.name}"
}

resource "aws_iam_role" "poudriere" {
  name_prefix = "poudriere"
  path        = "/"

  assume_role_policy = "${data.aws_iam_policy_document.ec2_assumerole.json}"
}

resource "aws_iam_policy" "poudriere" {
  name_prefix = "poudriere"
  description = "poudriere access to s3 and ec2"

  policy = "${data.aws_iam_policy_document.poudriere.json}"
}

resource "aws_iam_policy_attachment" "poudriere" {
  name       = "poudriere"
  roles      = ["${aws_iam_role.poudriere.name}"]
  policy_arn = "${aws_iam_policy.poudriere.arn}"
}
