variable "name" {
  default = "prometheus"
}

variable "instance_size" {
  # TODO change after tests
  default = "t3.small"
}

variable "availability_zone" {
  default = "us-east-1a"
}

variable "cloudmap_internal_id" {
}

variable "domain" {
  default = "folly-prometheus"
}

variable "ecs_cluster_private_security_group_id" {
}

variable "instance_profile_name" {
}

variable "instance_role_name" {
}

variable "region" {
  default = "us-east-1"
}

variable "security_group_id_jump_host" {
}

variable "vpc_id" {
}

variable "vpc_subnets" {
}

