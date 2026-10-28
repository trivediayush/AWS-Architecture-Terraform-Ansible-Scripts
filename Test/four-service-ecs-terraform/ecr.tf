locals {
  ecr_repos = toset(["frontend", "api", "bl", "mqtt"])
}

# Creating these repos does not build or push any image - the sample services
# pull from public registries. Push your own images here and repoint the
# *_image variables to switch over. Tags are MUTABLE so repeated pushes of a
# dev tag (e.g. "latest") work out of the box.
resource "aws_ecr_repository" "services" {
  for_each = local.ecr_repos

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${var.project_name}-ecr-${each.key}" }
}

# Keep repo growth bounded for a test env: expire untagged images after 7 days.
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = local.ecr_repos
  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}
