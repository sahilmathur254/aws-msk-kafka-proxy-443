#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_root"

./scripts/validate.sh
terraform -chdir=terraform init
terraform -chdir=terraform plan -out=tfplan

echo "Review terraform/tfplan, then run: terraform -chdir=terraform apply tfplan"
