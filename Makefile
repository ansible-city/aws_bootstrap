include .mk

ANSIBLE_CONFIG ?= tests/ansible.cfg
ANSIBLE_VERSION ?= 2.4
DEST ?= "change-me"
PWD = $(shell pwd)
REGION ?= eu-west-1
ROLE_NAME ?= $(shell basename $$(pwd))
VAGRANT_BOX ?= ubuntu/trusty64
VENV ?= $(PWD)/.venv

PATH := $(VENV)/bin:$(shell printenv PATH)
SHELL := env PATH=$(PATH) /bin/bash

export ANSIBLE_CONFIG
export AWS_DEFAULT_REGION=$(REGION)
export AWS_REGION=$(REGION)
export PATH
export VAGRANT_BOX

.DEFAULT_GOAL := help
.PHONY: help

## Run tests on any file change
watch:
	while sleep 1; do \
		find defaults/ meta/ tasks/ tests/test.yml \
		| entr -d $(MAKE) lint vagrant; \
	done

## Create symlink in given destination folder
# Usage:
#   make install.symlink DEST=~/workspace/my-project/ansible/roles/vendor
install.symlink:
	@if [ ! -d "$(DEST)" ]; then echo "DEST folder does not exists."; exit 1; fi;
	@ln -s $(PWD) $(DEST)/ansible-city.$(ROLE_NAME)
	@echo "intalled in $(DEST)/ansible-city.$(ROLE_NAME)"

## Lint role
# You need to install ansible-lint
lint: $(VENV)
	find defaults/ meta/ tasks/ -name "*.yml" | xargs -I{} ansible-lint {}

## Run tests
test: tests/roles/ansible-city.$(ROLE_NAME) lint test_ansible

## ! Executes Ansible tests using local connection
# run it ONLY from within a test VM.
# Example: make test_ansible
#          make test_ansible TEST_PLAYBOOK=test-something-else.yml
test_ansible: $(VENV) tests/roles/ansible-city.$(ROLE_NAME) test_ansible_build test_ansible_configure
	cd tests && ansible-playbook \
		--inventory inventory \
		--connection local \
		--tags assert \
		$(TEST_PLAYBOOK)

## ! Executes Ansible tests using local connection
# run it ONLY from witinh a test VM.
# Example: make test_ansible_build
#          make test_ansible_build TEST_PLAYBOOK=test-something-else.yml
test_ansible_%: $(VENV) tests/roles/ansible-city.$(ROLE_NAME)
	cd tests && ansible-playbook \
		--inventory inventory \
		--connection local \
		--tags=$(subst test_ansible_,,$@) \
		$(TEST_PLAYBOOK)
	cd tests && ansible-playbook \
		--inventory inventory \
		--connection local \
		--tags=$(subst test_ansible_,,$@) \
		$(TEST_PLAYBOOK) \
		| grep -q 'changed=0.*failed=0' \
			&& (echo 'Idempotence test: pass' && exit 0) \
			|| (echo 'Idempotence test: fail' && exit 1)

## Start and (re)provisiom Vagrant test box
vagrant: $(VENV) tests/roles/ansible-city.$(ROLE_NAME)
	cd tests && vagrant up --no-provision
	cd tests && vagrant provision
	@echo "- - - - - - - - - - - - - - - - - - - - - - -"
	@echo "           Provisioning Successful"
	@echo "- - - - - - - - - - - - - - - - - - - - - - -"

## Execute simple Vagrant command
# Example: make vagrant.ssh
#          make vagrant.halt
vagrant.%: $(VENV) tests/roles/ansible-city.$(ROLE_NAME)
	cd tests && vagrant $(subst vagrant.,,$@)

tests/roles/ansible-city.$(ROLE_NAME):
	@mkdir -p $(PWD)/tests/roles
	@ln -s $(PWD) $(PWD)/tests/roles/ansible-city.$(ROLE_NAME)

# install dependencies in virtualenv
$(VENV):
	@which virtualenv > /dev/null || (\
		echo "please install virtualenv: http://docs.python-guide.org/en/latest/dev/virtualenvs/" \
		&& exit 1 \
	)
	virtualenv $(VENV)
	$(VENV)/bin/pip install -U "pip<9.0"
	$(VENV)/bin/pip install pyopenssl urllib3[secure] requests[security]
	$(VENV)/bin/pip install -r requirements-$(ANSIBLE_VERSION).txt --ignore-installed
	virtualenv --relocatable $(VENV)

## Clean up
clean:
	rm -f .mk
	rm -rf $(VENV)
	rm -rf tests/roles
	cd tests && vagrant destroy

## Prints this help
help:
	@awk -v skip=1 \
		'/^##/ { sub(/^[#[:blank:]]*/, "", $$0); doc_h=$$0; doc=""; skip=0; next } \
		skip { next } \
		/^#/ { doc=doc "\n" substr($$0, 2); next } \
		/:/ { sub(/:.*/, "", $$0); printf "\033[34m%-30s\033[0m\033[1m%s\033[0m %s\n\n", $$0, doc_h, doc; skip=1 }' \
		$(MAKEFILE_LIST)

.mk:
	echo "" > .mk
