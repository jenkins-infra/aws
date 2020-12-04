
all: check

prepare:
	@terraform init

check: prepare
	@terraform validate

clean:
	@rm -rf $(CURDIR)/.terraform
