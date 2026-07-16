#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_root"

find scripts tests proxy/scripts -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python3 -m py_compile clients/transactions.py

if command -v shellcheck >/dev/null; then
  find scripts tests proxy/scripts -type f -name '*.sh' -print0 | xargs -0 shellcheck
else
  echo "WARN: shellcheck is not installed; skipped shell linting" >&2
fi

if command -v terraform >/dev/null; then
  terraform -chdir=terraform fmt -check -recursive
  terraform -chdir=terraform init -backend=false >/dev/null
  terraform -chdir=terraform validate
else
  echo "WARN: terraform is not installed; skipped Terraform fmt/validate" >&2
fi

if rg -n --hidden --glob '!*.example' --glob '!README.md' \
  '(sasl\.password\s*=|password\s*=\s*[^.]{8,}|-----BEGIN (RSA )?PRIVATE KEY-----)' .; then
  echo "FAIL: possible credential or private key found in a non-example project file" >&2
  exit 1
fi

echo "Static validation passed."
