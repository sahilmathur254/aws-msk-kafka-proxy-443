#!/usr/bin/env bash
set -euo pipefail

for command in aws terraform jq; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

tfvars=${1:-terraform/terraform.tfvars}
[[ -r "$tfvars" ]] || { echo "Terraform variables file not found: $tfvars" >&2; exit 1; }

terraform -chdir=terraform init -backend=false >/dev/null
terraform -chdir=terraform validate

echo "Terraform configuration is syntactically valid."
echo "Run 'terraform -chdir=terraform plan' to validate account-specific IDs, IAM permissions, DNS, and secret access."
