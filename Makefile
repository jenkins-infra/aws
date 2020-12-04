
all: check

prepare:
	@terraform init

check: prepare
	@terraform validate

sec:
	@tfsec

clean:
	@rm -rf $(CURDIR)/.terraform
