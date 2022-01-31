# resource "aws_ecs_cluster" "prometheus" {
#   name = var.name
# }

# output "cluster_name" {
#   value = aws_ecs_cluster.prometheus.name
# }

resource "aws_ecs_service" "prometheus" {
  name            = var.name
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1

  # No downtime deployment
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  # Prevent scheduling on same node two prometheus tasks
  placement_constraints {
    type = "distinctInstance"
  }

  network_configuration {
    security_groups = [aws_security_group.prometheus.id]
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibility in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    subnets = var.vpc_subnets
  }

  service_registries {
    registry_arn = var.cloudmap_arn
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family                = var.name
  network_mode          = "awsvpc"
  container_definitions = data.template_file.prometheus.rendered

  task_role_arn = aws_iam_role.prometheus.arn

  volume {
    name      = "config"
    host_path = "/etc/prometheus"
  }

  volume {
    name      = "data"
    host_path = "/var/lib/prometheus"
  }

  volume {
    name      = "grafana"
    host_path = "/var/lib/grafana"
  }

  volume {
    name      = "alertmanager"
    host_path = "/etc/alertmanager"
  }
}

data "template_file" "prometheus" {
  template = file("${path.module}/files/prometheus_task.json")

  vars = {
    aws_region = var.region
  }
}
