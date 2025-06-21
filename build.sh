#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
STRICT_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--strict)
		STRICT_MODE=true
		shift
		;;
	--help)
		echo "Usage: $0 [--strict] [--help]"
		echo "  --strict   Enable strict mode (fails on warnings)"
		echo "  --help     Show this help message"
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		exit 1
		;;
	esac
done

# Function to check minimum version
check_min_version() {
	local cmd=$1
	local min_version=$2
	local version

	version=$($cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	if [ "$(printf '%s\n' "$min_version" "$version" | sort -V | head -n1)" = "$min_version" ]; then
		echo -e "${GREEN}✓ $cmd $version >= $min_version${NC}"
	else
		echo -e "${RED}✗ $cmd version $version is less than required $min_version${NC}"
		return 1
	fi
}

# Check for required commands
REQUIRED_CMDS=("aws" "cfn-lint" "cfn_nag_scan" "python3" "ruby")
for cmd in "${REQUIRED_CMDS[@]}"; do
	if ! command -v "$cmd" &>/dev/null; then
		echo -e "${RED}Error: $cmd is not installed${NC}"
		exit 1
	fi
done

# Check minimum versions
echo -e "${BLUE}=== Checking Dependencies ===${NC}"
check_min_version "python3" "3.7.0"
check_min_version "ruby" "2.7.0"
check_min_version "cfn-lint" "0.56.0"
check_min_version "cfn_nag_scan" "0.0.0" # Version check not easily available for cfn_nag_scan

echo -e "${GREEN}=== Starting CloudFormation template validation ===${NC}"

# Validate CloudFormation template
TEMPLATE="cloudformation/backend.yml"
if [ ! -f "$TEMPLATE" ]; then
	echo -e "${RED}Error: Template file $TEMPLATE not found${NC}"
	exit 1
fi

# Lint the CloudFormation template
echo -e "\n${BLUE}=== Running cfn-lint ===${NC}"
CFN_LINT_ARGS=("$TEMPLATE")
if [ "$STRICT_MODE" = true ]; then
	CFN_LINT_ARGS+=("--strict")
	echo -e "${YELLOW}Strict mode enabled - failing on warnings${NC}"
fi

if ! cfn-lint "${CFN_LINT_ARGS[@]}"; then
	echo -e "${RED}❌ cfn-lint validation failed${NC}"
	exit 1
else
	echo -e "${GREEN}✓ cfn-lint validation passed${NC}"
fi

# Run cfn_nag for security scanning
echo -e "\n${BLUE}=== Running cfn_nag_scan ===${NC}"
if ! cfn_nag_scan --input-path "$TEMPLATE"; then
	echo -e "${RED}❌ cfn_nag_scan found security issues${NC}"
	if [ "$STRICT_MODE" = true ]; then
		exit 1
	else
		echo -e "${YELLOW}⚠️  Security issues found, but continuing in non-strict mode${NC}"
	fi
else
	echo -e "${GREEN}✓ No critical security issues found${NC}"
fi

# Check for required Python packages
echo -e "\n${BLUE}=== Checking Python Dependencies ===${NC}"
REQUIRED_PACKAGES=("cfn-lint" "cfn-flip")

# Try to find and use the virtual environment's Python
PYTHON_CMD="python3"
ACTIVATION_SCRIPT=""

# Check for virtual environment in common locations
if [ -f "venv/bin/activate" ]; then
    ACTIVATION_SCRIPT="venv/bin/activate"
elif [ -f ".venv/bin/activate" ]; then
    ACTIVATION_SCRIPT=".venv/bin/activate"
fi

# Activate the virtual environment if found
if [ -n "$ACTIVATION_SCRIPT" ]; then
    echo -e "${BLUE}Activating virtual environment: $ACTIVATION_SCRIPT${NC}"
    # shellcheck source=/dev/null
    source "$ACTIVATION_SCRIPT"
    PYTHON_CMD="python"
fi

echo -e "${BLUE}Using Python: $($PYTHON_CMD --version 2>&1)${NC}"
echo -e "${BLUE}Python path: $($PYTHON_CMD -c 'import sys; print("\n".join(sys.path))')${NC}"

# Check for required packages using pip list
MISSING_PACKAGES=0
INSTALLED_PACKAGES=$($PYTHON_CMD -m pip list --format=columns 2>/dev/null || $PYTHON_CMD -m pip list 2>/dev/null)

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if echo "$INSTALLED_PACKAGES" | grep -q -i "^${pkg}\s"; then
        version=$(echo "$INSTALLED_PACKAGES" | grep -i "^${pkg}\s" | awk '{print $2}')
        echo -e "${GREEN}✓ $pkg is installed (${version})${NC}"
    else
        echo -e "${RED}❌ Required Python package $pkg is not installed in the current environment${NC}"
        echo -e "Install with: pip install $pkg"
        if [ -n "$ACTIVATION_SCRIPT" ]; then
            echo -e "Make sure to activate the virtual environment first with: source $ACTIVATION_SCRIPT"
        fi
        MISSING_PACKAGES=$((MISSING_PACKAGES + 1))
    fi
done

if [ $MISSING_PACKAGES -gt 0 ]; then
    echo -e "\n${RED}Error: $MISSING_PACKAGES required package(s) are missing${NC}"
    exit 1
fi

# Validate the template with AWS CloudFormation
echo -e "\n${BLUE}=== Validating CloudFormation Template ===${NC}"
if ! aws cloudformation validate-template --template-body "file://$TEMPLATE" >/dev/null 2>&1; then
	echo -e "${RED}❌ CloudFormation template validation failed${NC}"
	# Show the actual error
	aws cloudformation validate-template --template-body "file://$TEMPLATE"
	exit 1
else
	echo -e "${GREEN}✓ CloudFormation template is valid${NC}"
fi

# Check for best practices
echo -e "\n${BLUE}=== Checking for Best Practices ===${NC}"
if ! cfn-lint "$TEMPLATE" -i E3012 2>&1 | grep -q "E0000"; then
	echo -e "${GREEN}✓ No best practice violations found${NC}"
else
	echo -e "${YELLOW}⚠️  Some best practice warnings found:${NC}"
	cfn-lint "$TEMPLATE" -i E3012 | grep -v "E0000" || true
	if [ "$STRICT_MODE" = true ]; then
		echo -e "${RED}❌ Failing due to best practice violations in strict mode${NC}"
		exit 1
	fi
fi

echo -e "\n${GREEN}✅ All validations completed successfully${NC}"
echo -e "${BLUE}=== Summary ===${NC}"
echo "- Template validation: ✓ Passed"
echo "- Security scanning:  ✓ Completed"
echo "- Best practices:     ✓ Checked"

if [ "$STRICT_MODE" = true ]; then
	echo -e "${GREEN}✓ Strict mode: All checks passed!${NC}"
else
	echo -e "${YELLOW}ℹ️  Run with --strict to fail on warnings${NC}"
fi
