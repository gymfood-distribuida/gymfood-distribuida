terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Importamos el rol preexistente de AWS Academy (prohibido crear roles nuevos)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

module "networking" {
  source      = "../../modules/networking"
  environment = "qa"
}

output "vpc_creada_id" {
  description = "ID de la VPC desplegada en AWS"
  value       = module.networking.vpc_id
}

output "lab_role_arn" {
  description = "ARN del rol de AWS Academy listo para ECS Fargate"
  value       = data.aws_iam_role.lab_role.arn
}

module "compute" {
  source             = "../../modules/compute"
  environment        = "qa"
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.networking.alb_sg_id
  bastion_sg_id      = module.networking.bastion_sg_id
  app_sg_id          = module.networking.app_sg_id
}

output "alb_dns" { value = module.compute.alb_dns_name }
output "bastion_ip" { value = module.compute.bastion_public_ip }

