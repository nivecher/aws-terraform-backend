#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEFAULT_STACK_NAME="terraform-backend"
DEFAULT_REGION="us-east-1"
DEFAULT_ENVIRONMENT="dev"
DEFAULT_PROJECT="terraform-backend"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--stack-name)
		STACK_NAME="$2"
		shift 2
		;;
	--region)
		AWS_REGION="$2"
		shift 2
		;;
	--environment)
		ENVIRONMENT="$2"
		shift 2
		;;
	--project)
		PROJECT="$2"
		shift 2
		;;
	--state-bucket-name)
		STATE_BUCKET_NAME="$2"
		shift 2
		;;
	--lock-table-name)
		LOCK_TABLE_NAME="$2"
		shift 2
		;;
	-h | --help)
		show_help
		exit 0
		;;
	*)
		echo -e "${RED}Unknown parameter: $1${NC}"
		show_help
		exit 1
		;;
	esac
done

# Show help function
show_help() {
	echo "Usage: $0 [OPTIONS]"
	echo "Deploy AWS Terraform Backend with CloudFormation"
	echo ""
	echo "Options:"
	echo "  --stack-name NAME         Name of the CloudFormation stack (default: $DEFAULT_STACK_NAME)"
	echo "  --region REGION          AWS region to deploy to (default: $DEFAULT_REGION)"
	echo "  --environment ENV        Environment name (e.g., dev, staging, prod) (default: $DEFAULT_ENVIRONMENT)"
	echo "  --project NAME           Project name for resource tagging (default: $DEFAULT_PROJECT)"
	echo "  --state-bucket-name NAME Custom S3 bucket name for Terraform state"
	echo "  --lock-table-name NAME   Custom DynamoDB table name for state locking"
	echo "  -h, --help               Show this help message"
	echo ""
}

# Set default values if not provided
STACK_NAME=${STACK_NAME:-$DEFAULT_STACK_NAME}
AWS_REGION=${AWS_REGION:-$(aws configure get region 2>/dev/null || echo "$DEFAULT_REGION")}
ENVIRONMENT=${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}
PROJECT=${PROJECT:-$DEFAULT_PROJECT}

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
	echo -e "${RED}AWS CLI is not configured. Please run 'aws configure'.${NC}"
	exit 1
fi

echo -e "${GREEN}=== Deploying Terraform Backend ===${NC}"
echo -e "Stack Name: ${YELLOW}$STACK_NAME${NC}"
echo -e "Region: ${YELLOW}$AWS_REGION${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Project: ${YELLOW}$PROJECT${NC}"

# Build parameters array
PARAMETERS=(
	"ParameterKey=Environment,ParameterValue=$ENVIRONMENT"
	"ParameterKey=Project,ParameterValue=$PROJECT"
)

# Add optional parameters if provided
if [[ -n "$STATE_BUCKET_NAME" ]]; then
	PARAMETERS+=("ParameterKey=StateBucketName,ParameterValue=$STATE_BUCKET_NAME")
fi

if [[ -n "$LOCK_TABLE_NAME" ]]; then
	PARAMETERS+=("ParameterKey=LockTableName,ParameterValue=$LOCK_TABLE_NAME")
fi

# Deploy the CloudFormation stack
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"

if aws cloudformation deploy \
	--region "$AWS_REGION" \
	--stack-name "$STACK_NAME" \
	--template-file cloudformation/backend.yml \
	--parameter-overrides "${PARAMETERS[@]}" \
	--capabilities CAPABILITY_NAMED_IAM; then

	echo -e "\n${GREEN}=== Deployment successful! ===${NC}"

	# Show stack outputs
	echo -e "\n${YELLOW}Stack Outputs:${NC}"
	aws cloudformation describe-stacks \
		--stack-name "$STACK_NAME" \
		--query 'Stacks[0].Outputs[*].{Key:OutputKey,Value:OutputValue}' \
		--output table \
		--region "$AWS_REGION"

	echo -e "\n${GREEN}Terraform Backend is ready to use!${NC}"
	echo -e "Configure your Terraform backend with the following settings:"
	echo -e "  bucket = \"$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`StateBucketName`].OutputValue' --output text --region "$AWS_REGION")\""
	echo -e "  key    = \"terraform.tfstate\""
	echo -e "  region = \"$AWS_REGION\""
	echo -e "  dynamodb_table = \"$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`LockTableName`].OutputValue' --output text --region "$AWS_REGION")\""

	exit 0
else
	echo -e "\n${RED}=== Deployment failed! ===${NC}"
	echo -e "Check the AWS CloudFormation console for details: https://${AWS_REGION}.console.aws.amazon.com/cloudformation/home?region=${AWS_REGION}#/stacks"
	exit 1
fi
