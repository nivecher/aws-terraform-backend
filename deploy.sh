#!/bin/bash
set -eo pipefail # script will exit on error

if [[ "${AWS_REGION}" == "" ]]; then
  AWS_REGION=$(aws configure get region) || true
fi

stack_name=$1
if [[ "$stack_name" == "" ]]; then
  stack_name="terraform-backend" # default name
fi
echo "Deploying terraform backend in region: ${AWS_REGION}"

# TODO add tags
aws cloudformation deploy --region ${AWS_REGION} --stack-name ${stack_name} \
  --template-file cloudformation/backend.yml \
  --capabilities CAPABILITY_NAMED_IAM
