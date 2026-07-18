#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_root"

./scripts/validate.sh
example_dir=examples/complete
terraform -chdir="$example_dir" init
terraform -chdir="$example_dir" plan -out=tfplan

echo "Review $example_dir/tfplan, then run: terraform -chdir=$example_dir apply tfplan"
