resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name         = "${var.name}/${each.key}"
  force_delete = var.force_delete

  # IMMUTABLE: a tag can never be overwritten. "v1" always means the same bytes.
  # This forces CI to tag with the git SHA, so what Argo CD deploys is traceable to one commit.
  image_tag_mutability = "IMMUTABLE"

  # Every pushed image is scanned for known CVEs. Results show up in the console and via the API.
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the most recent ${var.keep_last_images} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_last_images
      }
      action = { type = "expire" }
    }]
  })
}