# Allow EC2 scraping
# ECS task ROLE
resource "aws_iam_role" "prometheus" {
  name_prefix = "PrometheusTask-"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name               = "ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}


resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  depends_on = [
    aws_iam_role.ecs_agent
  ]
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs-agent"
  role = aws_iam_role.ecs_agent.name
}

resource "aws_iam_role_policy_attachment" "prometheus_ec2_scrape_policy" {
  role       = aws_iam_role.prometheus.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Allow ECS discovery
resource "aws_iam_policy" "prometheus_ecs_discovery_attachment" {
  name_prefix = "ecs_discovery_attachment-"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:List*",
                "ecs:Describe*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "prometheus_ecs_discovery_attachment" {
  policy_arn = aws_iam_policy.prometheus_ecs_discovery_attachment.arn
  role       = aws_iam_role.prometheus.name
}

# Additional required polcies for instance profile
# Allow S3 access to configuration
resource "aws_iam_policy" "prometheus_s3_access" {
  name_prefix = "s3-access-"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.config.id}/*",
                "arn:aws:s3:::${aws_s3_bucket.config.id}"
            ]
        }
    ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "prometheus_s3_access" {
  policy_arn = aws_iam_policy.prometheus_s3_access.arn
  role       = aws_iam_role.prometheus.id
}

# Allow EBS volume attachment
resource "aws_iam_policy" "prometheus_ebs_attachment" {
  name_prefix = "s3_ebs_attachment-"

  policy = jsonencode(
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:instance/*",
                "${aws_ebs_volume.prometheus.arn}",
                "${aws_ebs_volume.grafana.arn}",
            ]
        }
    ]
})

}


resource "aws_iam_policy" "logs" {
  name_prefix = "${var.name}-logs-policy-"

  policy = jsonencode(
{
    "Version" : "2012-10-17",
    "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
          ],
          "Resource" : [
              "*"
          ]
        }
    ]
})

}

resource "aws_iam_role_policy_attachment" "prometheus_ebs_attachment" {
  policy_arn = aws_iam_policy.prometheus_ebs_attachment.arn
  role       = aws_iam_role.prometheus.id
}

resource "aws_iam_role_policy_attachment" "prometheus_logs" {
  policy_arn = aws_iam_policy.logs.arn
  role       = aws_iam_role.prometheus.id
}

# Allow using Cloud Map
resource "aws_iam_role_policy_attachment" "prometheus_cloudmap_route53_policy" {
  role       = aws_iam_role.prometheus.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

