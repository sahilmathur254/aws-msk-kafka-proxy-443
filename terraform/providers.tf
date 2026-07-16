provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project   = var.name
        ManagedBy = "Terraform"
        Component = "msk-kafka-proxy-443"
      },
      var.tags
    )
  }
}
