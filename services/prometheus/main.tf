locals {
  config_bucket_name = "${var.name}.${var.domain}"
  # vpc_subnets        = split(",", var.vpc_subnets)

  az_map = {
    "us-east-1a" = 0
    "us-east-1b" = 1
    "us-east-1c" = 2
  }
}

# data "aws_subnet_ids" "private" {
#   vpc_id = var.vpc_id

#   tags = {
#     Tier = "Private"
#   }
# }

resource "aws_autoscaling_group" "prometheus" {
  name                      = var.name
  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  launch_configuration      = aws_launch_configuration.prometheus.name

  vpc_zone_identifier  = var.vpc_subnets
  termination_policies = ["OldestInstance"]
  # availability_zones   = [var.availability_zone]

  enabled_metrics = [
    "GroupTotalInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMinSize",
    "GroupMaxSize",
  ]

  tag {
    key                 = "Name"
    value               = "${var.name}-instance"
    propagate_at_launch = true
  }

  depends_on = [aws_launch_configuration.prometheus]
}

# EC2 cluster instances - booting script
data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["amazon"]

  # Pick latest Amazon Linux AMI v2 optimized for ECS
  name_regex = "amzn2-ami-ecs-hvm-2.0.*-x86_64-ebs"
}

resource "aws_launch_configuration" "prometheus" {
  name_prefix          = "${var.name}-"
  iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
  image_id             = data.aws_ami.ecs.image_id
  instance_type        = var.instance_size
  security_groups      = [aws_security_group.prometheus.id]
  user_data            = data.template_file.user_data.rendered

  depends_on = [aws_security_group.prometheus]

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 cluster instances - booting script
data "template_file" "user_data" {
  template = file("${path.module}/files/userdata.yml")

  vars = {
    aws_region        = var.region
    bucket_config     = aws_s3_bucket.config.id
    ebs_id_prometheus = aws_ebs_volume.prometheus.id
    ebs_id_grafana    = aws_ebs_volume.grafana.id
    cluster_name      = var.ecs_cluster_name
  }
}

resource "aws_security_group" "prometheus" {
  name        = var.name
  description = "${var.name} Security Group"
  vpc_id      = var.vpc_id
  # subnets = var.vpc_public_subnets

  tags = {
    Name = "${var.name}-${var.name}-alb"
  }
}

output "security_group_id" {
  value = aws_security_group.prometheus.id
}

resource "aws_security_group_rule" "egress" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = -1
  security_group_id = aws_security_group.prometheus.id
  to_port           = 0
  type              = "egress"
}

# Allow access from jump host
resource "aws_security_group_rule" "allow_jump_host_ssh" {
  from_port                = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.prometheus.id
  cidr_blocks       = [var.cidr_block]
  to_port                  = 22
  type                     = "ingress"
}

resource "aws_security_group_rule" "allow_jump_host_http_prometheus" {
  from_port                = 9090
  protocol                 = "tcp"
  security_group_id        = aws_security_group.prometheus.id
  cidr_blocks       = [var.cidr_block]
  to_port                  = 9090
  type                     = "ingress"
}

resource "aws_security_group_rule" "allow_jump_host_http_grafana" {
  from_port                = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.prometheus.id
cidr_blocks       = [var.cidr_block]
  to_port                  = 3000
  type                     = "ingress"
}

resource "aws_security_group_rule" "allow_jump_host_http_alertmanager" {
  from_port                = 9093
  protocol                 = "tcp"
  security_group_id        = aws_security_group.prometheus.id
  cidr_blocks       = [var.cidr_block]
  to_port                  = 9093
  type                     = "ingress"
}

