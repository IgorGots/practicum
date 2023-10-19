export ENV_FILE := .env
include $(ENV_FILE)							# for Makefile debug
export $(shell sed 's/=.*//' $(ENV_FILE))	# for tasks inside Makefile


all: validate plan apply

validate:
		terraform validate

plan:
		terraform plan

apply:
		terraform apply -auto-approve

output:
		terraform refresh
		terraform output

yc:
		yc resource-manager cloud list
		yc resource-manager folder list

run:
		./bin/run.sh

_init:
		terraform init

_destroy:
		terraform destroy

