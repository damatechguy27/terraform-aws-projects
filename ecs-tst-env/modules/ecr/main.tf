locals {
  lifecycle_rules = concat(
    var.lifecycle_keep_last_n_tagged > 0 ? [{
      rulePriority = 1
      description  = "Keep last ${var.lifecycle_keep_last_n_tagged} tagged images"
      selection = {
        tagStatus      = "tagged"
        tagPatternList = ["*"]
        countType      = "imageCountMoreThan"
        countNumber    = var.lifecycle_keep_last_n_tagged
      }
      action = { type = "expire" }
    }] : [],
    var.lifecycle_untagged_expire_days > 0 ? [{
      rulePriority = 2
      description  = "Expire untagged images after ${var.lifecycle_untagged_expire_days} days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.lifecycle_untagged_expire_days
      }
      action = { type = "expire" }
    }] : [],
  )
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  count = length(local.lifecycle_rules) > 0 ? 1 : 0

  repository = aws_ecr_repository.this.name
  policy     = jsonencode({ rules = local.lifecycle_rules })
}
