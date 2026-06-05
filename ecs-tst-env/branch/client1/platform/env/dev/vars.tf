# Image tags are no longer passed in as a variable: each service auto-resolves the
# latest image from the shared ECR repo by tag prefix (see data.external.latest_image
# in data.tf and local.services in locals.tf).
