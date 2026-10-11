DIRS := $(wildcard modules/*) examples/complete
TRIVY_IMAGE  := aquasec/trivy:0.75.0
TFLINT_IMAGE := ghcr.io/terraform-linters/tflint:v0.64.0

.PHONY: help fmt validate test lint scan ci

help: ## Show targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

fmt: ## Format all Terraform
	terraform fmt -recursive

validate: ## terraform validate every module and the example
	@for d in $(DIRS); do echo "== $$d"; terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate || exit 1; done

test: ## terraform test (mocked AWS, no credentials needed)
	@for d in $(DIRS); do echo "== $$d"; terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d test || exit 1; done

lint: ## tflint with the AWS ruleset (Docker)
	docker run --rm -v "$(CURDIR)":/data -w /data --entrypoint sh $(TFLINT_IMAGE) -c "tflint --init && tflint --recursive --config /data/.tflint.hcl"

scan: ## Trivy IaC misconfiguration scan, fails on HIGH/CRITICAL (Docker)
	docker run --rm -v "$(CURDIR)":/src -w /src $(TRIVY_IMAGE) config --severity HIGH,CRITICAL --exit-code 1 .

ci: ## Everything CI runs
	terraform fmt -check -recursive
	$(MAKE) validate test lint scan
