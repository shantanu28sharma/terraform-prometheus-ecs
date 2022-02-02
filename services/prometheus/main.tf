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

  vpc_zone_identifier  = var.vpc_public_subnets
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

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.name
  public_key = tls_private_key.example.public_key_openssh
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
  user_data            = <<EOF
yum update -y
yum install -y aws-cli ec2-instance-connect jq

yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent

touch /root/init.sh
touch /root/config_sync.sh

echo ECS_CLUSTER=${var.ecs_cluster_name} >> /etc/ecs/ecs.config
echo AWS_DEFAULT_REGION=${var.region} >> /etc/ecs/ecs.config

chmod 0755 /root/config_sync.sh
chmod 0755 /root/init.sh

echo set -ex >> /root/config_sync.sh
echo aws s3 cp --recursive s3://${aws_s3_bucket.config.id}/prometheus /etc/prometheus/ >> /root/config_sync.sh
echo aws s3 cp --recursive s3://${aws_s3_bucket.config.id}/alertmanager /etc/alertmanager/ >> /root/config_sync.sh

echo AWS_EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone` >> /root/init.sh
echo AWS_INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id` >> /root/init.sh
echo aws ec2 attach-volume --volume-id ${aws_ebs_volume.prometheus.id} --instance-id $AWS_INSTANCE_ID --device /dev/xvdx --region us-east-1 >> /root/init.sh
echo aws ec2 attach-volume --volume-id ${aws_ebs_volume.grafana.id}    --instance-id $AWS_INSTANCE_ID --device /dev/xvdz --region us-east-1 >> /root/init.sh
echo sleep 10 >> /root/init.sh
echo mkdir -p /var/lib/prometheus >> /root/init.sh
echo mount /dev/nvme1n1 /var/lib/prometheus >> /root/init.sh
echo chown 65534:65534 /var/lib/prometheus/  >> /root/init.sh
echo mkdir -p /var/lib/grafana >> /root/init.sh
echo mount /dev/nvme2n1 /var/lib/grafana >> /root/init.sh
echo chown 472:472 /var/lib/grafana/ >> /root/init.sh

/bin/bash /root/config_sync.sh
/bin/bash /root/init.sh
EOF
  key_name      = "prometheus-2"
  associate_public_ip_address = true
  depends_on = [aws_security_group.prometheus]

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 cluster instances - booting script
data "template_file" "script" {
  template = file("${path.module}/files/script.tpl")

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
  from_port                = 0
  protocol                 = -1
  security_group_id        = aws_security_group.prometheus.id
  cidr_blocks              = ["0.0.0.0/0"]
  to_port                  = 0
  type                     = "ingress"
}

