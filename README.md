# New Relic Distributed Tracing AWS Demo

This project demonstrates distributed tracing across multiple AWS services using New Relic and OpenTelemetry. The architecture includes:

**CLI** → **OpenTelemetry** → **API Gateway** → **Lambda** → **SQS** → **AWS Batch** → **Step Functions** (Lambda → Lambda)

## Architecture Overview

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     CLI     │───▶│ API Gateway │───▶│   Lambda    │───▶│     SQS     │
│             │    │             │    │  (Handler)  │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                 │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │
│Step Function│◀───│ AWS Batch   │◀───│   Lambda    │◀──────────┘
│             │    │             │    │(SQS Process)│
└─────────────┘    └─────────────┘    └─────────────┘
       │
       ▼
┌─────────────┐    ┌─────────────┐
│   Lambda1   │───▶│   Lambda2   │
│             │    │             │
└─────────────┘    └─────────────┘
```

Each service propagates New Relic trace IDs, allowing you to see the complete request flow in New Relic's distributed tracing interface.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Docker (for building Batch job image)
- Node.js >= 18
- New Relic account and license key
- `jq` command-line tool

## Setup Instructions

### 1. Clone and Configure

```bash
# Copy environment configuration
cp .env.example .env
# Edit .env with your New Relic license key

# Copy Terraform configuration
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your settings
```

### 2. Deploy Infrastructure

```bash
# Run the deployment script
./deploy.sh
```

This script will:
- Install all Node.js dependencies
- Initialize and apply Terraform configuration
- Build and push the Docker image to ECR
- Display the API Gateway URL

### 3. Test the System

```bash
# Navigate to CLI directory
cd cli

# Install CLI dependencies (if not done by deploy script)
npm install

# Test the tracing (replace URL with your API Gateway URL)
node index.js send -u https://your-api-id.execute-api.region.amazonaws.com/prod/trace -m "Hello World"

# Test CLI tracing setup
node index.js test
```

### 4. Monitor in New Relic

1. Log into your New Relic account
2. Navigate to APM & Services
3. Look for applications with names like:
   - `newrelic-tracing-api-gateway`
   - `newrelic-tracing-sqs-processor`
   - `newrelic-tracing-batch-job`
   - `newrelic-tracing-step-function-lambda1`
   - `newrelic-tracing-step-function-lambda2`
   - `newrelic-tracing-cli`
4. Go to Distributed Tracing to see the complete trace flow

## Service Flow Details

1. **CLI Client**: Initiates a traced request using OpenTelemetry
2. **API Gateway**: Receives the request and forwards to Lambda
3. **Lambda Handler**: Processes request and sends message to SQS
4. **SQS**: Queues the message with trace context
5. **SQS Processor Lambda**: Processes SQS message and submits Batch job
6. **AWS Batch**: Runs containerized job with trace propagation
7. **Step Functions**: Executes state machine with two Lambda functions
8. **Lambda1 & Lambda2**: Process data sequentially, maintaining trace context

Each service logs its trace ID and span ID, allowing you to correlate logs and traces across the entire system.

## Configuration Files

### Environment Variables

- `.env`: Local environment configuration
- `terraform/terraform.tfvars`: Terraform variables

### New Relic Configuration

Each service includes a `newrelic.js` configuration file with:
- Application naming
- Distributed tracing enabled
- Log forwarding enabled

### OpenTelemetry Configuration

- `opentelemetry-config.js`: Shared OTEL configuration
- Individual service instrumentation in each Lambda function

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure your AWS credentials have sufficient permissions for all services
2. **ECR Push Fails**: Make sure Docker is running and you're authenticated to ECR
3. **Traces Not Appearing**: Verify New Relic license key is correct in all configurations
4. **Lambda Timeouts**: Check CloudWatch logs for specific error messages

### Logs and Monitoring

- **CloudWatch Logs**: Each Lambda function logs to CloudWatch with trace IDs
- **New Relic Logs**: Application logs are forwarded to New Relic
- **X-Ray**: AWS X-Ray tracing is also enabled for additional visibility

### Debug Commands

```bash
# Check Terraform outputs
cd terraform && terraform output

# Test CLI tracing only
cd cli && node index.js test

# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/newrelic-tracing"

# Check Batch job logs
aws logs describe-log-groups --log-group-name-prefix "/aws/batch/job"
```

## Cleanup

To remove all deployed resources:

```bash
./cleanup.sh
```

**Warning**: This will permanently delete all resources. Make sure you no longer need the infrastructure.

## Architecture Components

### Terraform Infrastructure

- **VPC**: Custom VPC with public/private subnets
- **API Gateway**: REST API endpoint
- **Lambda Functions**: 4 functions for different processing stages
- **SQS**: Message queue for asynchronous processing
- **AWS Batch**: Container-based compute environment
- **Step Functions**: State machine orchestration
- **ECR**: Container registry for Batch jobs
- **IAM**: Roles and policies for service permissions

### Application Components

- **CLI**: Node.js CLI with OpenTelemetry instrumentation
- **Lambda Functions**: New Relic and OpenTelemetry enabled
- **Batch Job**: Containerized Node.js application
- **Trace Propagation**: W3C trace context headers across all services

## Cost Considerations

This demo uses several AWS services that may incur charges:
- Lambda invocations and duration
- API Gateway requests
- SQS messages
- Batch compute time
- Step Functions state transitions
- ECR storage
- VPC NAT Gateway
- CloudWatch logs storage

Consider running the cleanup script when you're done testing to avoid ongoing charges.

## Contributing

This is a demonstration project. For production use, consider:
- Error handling and retry logic
- Security best practices
- Cost optimization
- Performance tuning
- Monitoring and alerting setup