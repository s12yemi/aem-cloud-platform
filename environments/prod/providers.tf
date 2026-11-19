provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "aem-cloud-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "portfolio-lab"
    }
  }
}
