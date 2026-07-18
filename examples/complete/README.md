# Complete example

This example deploys the local `terraform/` module against an existing VPC and
Amazon MSK cluster.

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

`terraform.tfvars` is ignored by Git. Do not put TLS private-key material or
Kafka credentials in it; `tls_secret_arn` must reference a pre-existing Secrets
Manager secret.

Destroy only the resources managed by this example:

```bash
terraform destroy
```
