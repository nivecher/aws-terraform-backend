# AWS Terraform Backend

This CloudFormation template creates a secure and production-ready Terraform backend with S3 for state storage and DynamoDB for state locking. Using this template avoids the chicken-and-egg problem of needing to use Terraform to create a state backend before you have a state backend for that Terraform configuration.

## Features

- **Secure by Default**:

  - Server-side encryption for S3 bucket (AES-256)
  - KMS encryption for DynamoDB table
  - Enforced encryption on all S3 operations
  - Versioning enabled for state bucket
  - Point-in-time recovery for DynamoDB

- **Operational Excellence**:

  - CloudTrail logging for all S3 bucket access
  - Comprehensive tagging for cost allocation
  - Automated deployment with GitHub Actions
  - Infrastructure as Code best practices

- **Security & Compliance**:

  - IAM least-privilege principles
  - Dedicated KMS key for DynamoDB
  - Secure bucket policies
  - Resource retention policies

## Prerequisites

- AWS CLI configured with appropriate permissions
- Python 3.8+ (for build tools)
- cfn-lint and cfn_nag (installed via `pip install -r requirements.txt`)

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| StateBucketName | String | "" | Name of the S3 bucket for Terraform state (auto-generated if empty) |
| LockTableName | String | "terraform-lock" | Name of the DynamoDB table for state locking |
| Environment | String | "dev" | Environment name (e.g., dev, staging, prod) |
| Project | String | "terraform-backend" | Project name for resource tagging |

## Resources

- **S3 Bucket**

  - Encrypted with AES-256
  - Versioning enabled
  - Secure bucket policy
  - Note: Access logging is disabled by default to prevent circular dependencies. For production use, consider enabling access logging to a separate logging bucket.

- **DynamoDB Table**

  - Note: Uses an explicit name to maintain consistency across deployments. Changing the table name will create a new table and require manual migration of any existing lock states.
  - CloudTrail logging

- **DynamoDB Table**

  - Encrypted with KMS
  - Point-in-time recovery enabled
  - Provisioned capacity

- **KMS Key**

  - For DynamoDB encryption
  - Secure key policy
  - Automatic key rotation

- **CloudTrail**

  - S3 bucket access logging
  - Log file validation
  - Secure bucket policy

## Deployment

### Manual Deployment

```bash
# Install dependencies
pip install -r requirements.txt

# Run linting and validation
./build.sh

# Deploy the stack
./deploy.sh \
  --stack-name my-terraform-backend \
  --region us-east-1 \
  --environment dev \
  --project my-project
```

### GitHub Actions

The repository includes a GitHub Actions workflow that automates the deployment process:

1. Linting and validation
1. Security scanning with cfn_nag
1. Deployment to AWS

To trigger a deployment:

1. Go to the "Actions" tab in your GitHub repository
1. Select the "Deploy Terraform Backend" workflow
1. Click "Run workflow"
1. Fill in the required parameters
1. Click "Run workflow"

## Outputs

| Output | Description |
|--------|-------------|
| StackName | Name of the CloudFormation stack |
| Region | AWS region where resources are deployed |
| StateBucketName | Name of the S3 bucket containing Terraform state |
| LockTableName | Name of the DynamoDB table used for state locking |
| KmsKeyArn | ARN of the KMS key used for DynamoDB encryption |
| CloudTrailBucketName | Name of the S3 bucket containing CloudTrail logs |

## Security

- All resources are tagged with environment and project names
- Least-privilege IAM policies
- Encryption at rest and in transit
- Secure defaults for all resources

## Cost Estimation

- **KMS Key**: $1/month
- **DynamoDB Table**: ~$0.65/month (5 RCU/WCU)
- **S3 Storage**: ~$0.023/GB/month
- **CloudTrail**: First trail is free, additional trails $2/trail/month

## Contributing

1. Fork the repository
1. Create a feature branch
1. Make your changes
1. Run `./build.sh` to validate
1. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)
[![cfn-lint](https://github.com/aws-cloudformation/cfn-lint/actions/workflows/cfn-lint.yml/badge.svg)](https://github.com/aws-cloudformation/cfn-lint/actions/workflows/cfn-lint.yml)
