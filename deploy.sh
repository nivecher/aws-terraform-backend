#!/bin/bash
set -eo pipefail # script will exit on error

region=$(aws configure get region)
stack_name=$1
if [[ "$stack_name" == "" ]]; then
  stack_name="terraform-backend" # default name
fi
echo "Deploying terraform backend in region: ${region}"

# TODO add tags
aws cloudformation deploy --region ${region} --stack-name ${stack_name} \
  --template-file file://cloudformation/backend.yml \
  --capabilities CAPABILITY_NAMED_IAM
