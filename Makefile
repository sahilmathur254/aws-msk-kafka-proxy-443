SHELL := /usr/bin/env bash

.PHONY: fmt validate plan apply destroy test metadata ports archive

fmt:
	terraform -chdir=terraform fmt -recursive

validate:
	./scripts/validate.sh

plan:
	terraform -chdir=terraform init
	terraform -chdir=terraform plan -out=tfplan

apply:
	terraform -chdir=terraform apply tfplan

destroy:
	terraform -chdir=terraform destroy

test:
	./tests/test-produce-consume.sh
	./tests/test-admin-operations.sh
	./tests/test-consumer-group.sh

metadata:
	./tests/verify-metadata.sh

ports:
	./tests/verify-port-usage.sh

archive:
	cd .. && zip -r aws-msk-kafka-proxy-443.zip aws-msk-kafka-proxy-443 \
		-x '*/.terraform/*' '*/tfplan' '*/.env' '*/__pycache__/*'
