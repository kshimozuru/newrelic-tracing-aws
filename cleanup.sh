#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧹 Cleaning up New Relic tracing demo resources${NC}"

cd terraform

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}❌ No terraform state found. Nothing to cleanup.${NC}"
    exit 0
fi

echo -e "${YELLOW}📋 Planning destruction...${NC}"
terraform plan -destroy

read -p "Are you sure you want to destroy all resources? This cannot be undone. (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

echo -e "${RED}🗑️  Destroying resources...${NC}"
terraform destroy -auto-approve

echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo -e "${YELLOW}Note: ECR repository images may still exist and incur charges.${NC}"
echo -e "${YELLOW}You may want to manually delete Docker images from ECR if no longer needed.${NC}"