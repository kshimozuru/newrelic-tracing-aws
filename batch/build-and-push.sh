#!/bin/bash

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <aws-region> <ecr-repository-url>"
  echo "Example: $0 ap-northeast-1 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/newrelic-tracing-batch-job"
  exit 1
fi

AWS_REGION=$1
ECR_REPO_URL=$2

echo "Building Docker image for Batch job..."
docker build -t newrelic-tracing-batch-job .

echo "Tagging image for ECR..."
docker tag newrelic-tracing-batch-job:latest $ECR_REPO_URL:latest

echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

echo "Pushing image to ECR..."
docker push $ECR_REPO_URL:latest

echo "Image pushed successfully: $ECR_REPO_URL:latest"