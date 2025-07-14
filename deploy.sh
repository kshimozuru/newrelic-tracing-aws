#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting deployment of New Relic distributed tracing demo${NC}"

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform/terraform.tfvars not found!${NC}"
    echo -e "${YELLOW}Please copy terraform.tfvars.example to terraform.tfvars and fill in your values${NC}"
    exit 1
fi

# Check if .env file exists for CLI
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file not found, copying from .env.example${NC}"
    cp .env.example .env
    echo -e "${YELLOW}Please edit .env file with your New Relic license key${NC}"
fi

cd terraform

echo -e "${GREEN}📦 Installing dependencies for Lambda functions...${NC}"

# Install dependencies for all Lambda functions
for dir in ../lambda/*/; do
    if [ -f "$dir/package.json" ]; then
        echo "Installing dependencies for $(basename $dir)..."
        (cd "$dir" && npm install --production)
    fi
done

for dir in ../lambda/step-functions/*/; do
    if [ -f "$dir/package.json" ]; then
        echo "Installing dependencies for $(basename $dir)..."
        (cd "$dir" && npm install --production)
    fi
done

# Install dependencies for Batch job
echo "Installing dependencies for Batch job..."
(cd ../batch && npm install --production)

# Install dependencies for CLI
echo "Installing dependencies for CLI..."
(cd ../cli && npm install)

echo -e "${GREEN}🔧 Initializing Terraform...${NC}"
terraform init

echo -e "${GREEN}📋 Planning Terraform deployment...${NC}"
terraform plan

read -p "Do you want to apply this plan? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

echo -e "${GREEN}🏗️  Applying Terraform configuration...${NC}"
terraform apply -auto-approve

# Get ECR repository URL for Docker build
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
AWS_REGION=$(terraform output -json | jq -r '.aws_region.value // "ap-northeast-1"')

echo -e "${GREEN}🐳 Building and pushing Docker image to ECR...${NC}"
cd ../batch
./build-and-push.sh $AWS_REGION $ECR_REPO_URL

cd ../terraform

# Get API Gateway URL
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo -e "${GREEN}📋 Deployment Summary:${NC}"
echo -e "API Gateway URL: ${YELLOW}$API_GATEWAY_URL${NC}"
echo -e "ECR Repository: ${YELLOW}$ECR_REPO_URL${NC}"
echo ""
echo -e "${GREEN}🧪 Testing the deployment:${NC}"
echo -e "1. Update your .env file with the API Gateway URL:"
echo -e "   ${YELLOW}API_GATEWAY_URL=$API_GATEWAY_URL${NC}"
echo ""
echo -e "2. Test the CLI:"
echo -e "   ${YELLOW}cd cli${NC}"
echo -e "   ${YELLOW}node index.js send -u $API_GATEWAY_URL -m \"Hello World\"${NC}"
echo ""
echo -e "${GREEN}🔍 Monitor traces in New Relic:${NC}"
echo -e "Visit your New Relic account to see distributed traces across all services"