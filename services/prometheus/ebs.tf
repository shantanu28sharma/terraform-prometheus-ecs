resource "aws_ebs_volume" "prometheus" {
  availability_zone = var.availability_zone
  size              = 5

  tags = {
    Name = "${var.name} - prometheus"
  }
}

resource "aws_ebs_volume" "grafana" {
  availability_zone = var.availability_zone
  size              = 5

  tags = {
    Name = "${var.name} - grafana"
  }
}

