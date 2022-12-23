# AWS Terraform Backend

This CloudFormation template creates an S3 bucket and DynamoDB table suitable
for a \[Terraform S3 State Backend\]. Using this template avoids the problem of
needing to use a Terraform module to create a state backend before you have a
state backend for that module.

## Features

- Encrypts Terraform state using a dedicated KMS key.
- Creates a dedicated IAM role with only the permissions needed to manage
  Terraform state.
- Sets up access logging for the state bucket using CloudTrail.

## Parameters

- __`StateBucketName`__ (`String`): Name of the S3 bucket used to store the
  terraform state
- __`LockTableName`__ (`String`): Name of the DynamoDB table to store the
  terraform state lock

## Resources

- __`LockTable`__ (`AWS::DynamoDB::Table`): DynamoDB table to lock Terraform
- __`StateBucket`__ (`AWS::S3::Bucket`): Bucket containing Terraform state
- __`StateBucketPolicy`__ (`AWS::S3::BucketPolicy`): Bucket policy for the state
  bucket enforcing encryption

## Outputs

- __`StackName`__: Name of the CloudFormation stack
- __`Region`__: Region in which the S3 state backend resources are created
- __`StateBucketName`__: Name of the S3 bucket containing Terraform state
- __`LockTableName`__: Name of the DynamoDB table used to lock Terraform state

## Capabilities

- __`CAPABILITY_NAMED_IAM`__: Required to create the dedicated IAM role.

## Cost

<!-- TODO add KMS -->

The KMS key provisioned for this stack will cost $1/month. Additional charges
for KMS, DynamoDB, S3, and Cloudtrail may occur but are insignificant.

[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)
