locals {
  region = "eu-west-2"
  name   = "checkout-homework"
  profile = "default"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  cluster_version = 1.29
  metrics_server_verion = "3.12.1"
  alb_chart_verion = "1.7.2"

  tags = {
    Name       = "checkout-infra"
    Type       = "homework"
  }
}