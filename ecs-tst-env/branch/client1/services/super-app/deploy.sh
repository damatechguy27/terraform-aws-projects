#!/usr/bin/env bash
#
# deploy.sh — Build a Docker image and push it to ECR.
#
# Hands the resulting tag back so Terraform can roll the task definition.
# This script intentionally does NOT touch ECS — task definition + service
# are owned by Terraform. The deploy loop is:
#
#   TAG=$(./deploy.sh | jq -r .tag)
#   terraform -chdir=../infra/env/dev apply -var "container_image_tag=$TAG"
#
# Required env vars:
#   APP_NAME       App folder under services/ and prefix for the image tag (e.g. "hello-app")
#   AWS_REGION     e.g. "us-west-2"
#   ECR_REPO_URL   Full repo URL, e.g. "123.dkr.ecr.us-west-2.amazonaws.com/client1-infra-dev-api"
#
# Optional env vars (with defaults):
#   BUILD_CONTEXT  Docker build context dir   (default: <script_dir>/<APP_NAME>)
#   DOCKERFILE     Path to dockerfile          (default: <BUILD_CONTEXT>/dockerfile)
#   PLATFORM       Target platform             (default: linux/amd64)
#
# Typical invocation (auto-discovers ECR URL from terraform output):
#
#   TF_DIR=../infra/env/dev
#   export AWS_REGION=us-west-2
#   export APP_NAME=hello-app
#   export ECR_REPO_URL=$(terraform -chdir=$TF_DIR output -raw ecr_api_repository_url)
#   ./deploy.sh
#
set -euo pipefail

# ---------- prerequisites ----------
for cmd in docker aws openssl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' is required but not installed." >&2; exit 1; }
done

# ---------- required vars ----------
: "${APP_NAME:?must set APP_NAME}"
: "${AWS_REGION:?must set AWS_REGION}"
: "${ECR_REPO_URL:?must set ECR_REPO_URL}"

# ---------- optional vars ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONTEXT="${BUILD_CONTEXT:-$SCRIPT_DIR}"
DOCKERFILE="${DOCKERFILE:-$BUILD_CONTEXT/dockerfile}"
PLATFORM="${PLATFORM:-linux/amd64}"

# ---------- 1. compute tag: <app>-<UTC date>-<random hex> ----------
DATE_STAMP="$(date -u +%Y%m%d-%H%M%S)"
RAND_HASH="$(openssl rand -hex 4)"
IMAGE_TAG="${APP_NAME}-${RAND_HASH}-${DATE_STAMP}"
IMAGE_URI="${ECR_REPO_URL}:${IMAGE_TAG}"

# Progress goes to stderr so stdout stays parseable (jq-friendly).
echo "==> Image tag: ${IMAGE_TAG}" >&2
echo "==> Image URI: ${IMAGE_URI}" >&2

# ---------- 2. ECR login ----------
ECR_REGISTRY="${ECR_REPO_URL%%/*}"
echo "==> Authenticating docker to ${ECR_REGISTRY}" >&2
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY" >&2

# ---------- 3. build + push ----------
echo "==> Building ${IMAGE_URI} (platform=${PLATFORM})" >&2
docker buildx build \
  --platform "$PLATFORM" \
  --file "$DOCKERFILE" \
  --tag "$IMAGE_URI" \
  --push \
  "$BUILD_CONTEXT" >&2

echo "==> Push complete." >&2

# ---------- 4. machine-readable summary on stdout ----------
cat <<EOF
{
  "image_tag": "${IMAGE_TAG}",
  "image_uri": "${IMAGE_URI}"
}
EOF
