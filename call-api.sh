#!/bin/bash

# New Relic Tracing AWS - Simple API Gateway Caller
# Usage: ./call-api.sh [message] [additional_data]

set -e

# Load environment variables from .env file
load_env() {
    if [ -f ".env" ]; then
        export $(grep -v '^#' .env | grep -v '^$' | xargs)
        echo "✅ Environment variables loaded from .env"
    else
        echo "❌ .env file not found. Please create one from .env.example"
        exit 1
    fi
}

# Get API Gateway URL from Terraform output
get_api_url() {
    if [ -d "terraform" ] && command -v terraform &> /dev/null; then
        cd terraform
        API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
        cd ..
        if [ -n "$API_URL" ]; then
            echo "✅ API Gateway URL: $API_URL"
        else
            echo "❌ Could not get API Gateway URL from Terraform"
            echo "💡 Please ensure Terraform is applied or set API_GATEWAY_URL in .env"
            API_URL="${API_GATEWAY_URL:-}"
        fi
    else
        echo "⚠️  Terraform not found, using URL from .env"
        API_URL="${API_GATEWAY_URL:-}"
    fi
    
    if [ -z "$API_URL" ]; then
        echo "❌ API Gateway URL not found"
        echo "💡 Set API_GATEWAY_URL in .env or deploy with Terraform"
        exit 1
    fi
}

# Generate W3C compatible trace ID (32 hex characters / 16 bytes)
generate_trace_id() {
    # Generate 32 hex characters (16 bytes) for W3C/New Relic compatibility
    # Using timestamp + random data to ensure uniqueness
    local timestamp_hex=$(printf "%08x" $(date +%s))
    local random_hex=$(openssl rand -hex 12 2>/dev/null || dd if=/dev/urandom bs=12 count=1 2>/dev/null | xxd -p -c 12)
    echo "${timestamp_hex}${random_hex}" | head -c 32
}

# Send request to API Gateway
send_request() {
    local message="${1:-Hello from Shell}"
    local additional_data="${2:-{}}"
    local trace_id=$(generate_trace_id)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Create JSON payload
    local json_payload
    if [ "$additional_data" = "{}" ]; then
        json_payload=$(cat <<EOF
{
    "message": "$message",
    "timestamp": "$timestamp",
    "source": "shell-script",
    "traceId": "$trace_id"
}
EOF
)
    else
        # Merge additional data
        json_payload=$(cat <<EOF
{
    "message": "$message",
    "timestamp": "$timestamp",
    "source": "shell-script",
    "traceId": "$trace_id",
    "additionalData": $additional_data
}
EOF
)
    fi
    
    echo "🚀 Sending request to API Gateway..."
    echo "📝 Message: $message"
    echo "🔍 Trace ID: $trace_id"
    echo "🎯 URL: $API_URL"
    echo ""
    
    # Send HTTP request with curl
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "User-Agent: NewRelic-Tracing-Shell/1.0" \
        -H "X-Trace-Id: $trace_id" \
        -d "$json_payload" \
        "$API_URL")
    
    # Extract HTTP status code
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    echo "📊 Response:"
    echo "HTTP Status: $http_code"
    
    if [ "$http_code" = "200" ]; then
        echo "✅ Success!"
        echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
        
        # Extract trace ID from response if available
        local api_trace_id=$(echo "$response_body" | jq -r '.traceId // empty' 2>/dev/null)
        if [ -n "$api_trace_id" ]; then
            echo ""
            echo "🔗 Trace Information:"
            echo "Shell Trace ID: $trace_id"
            echo "API Gateway Trace ID: $api_trace_id"
            echo ""
            echo "💡 Check New Relic Dashboard for distributed trace visualization"
        fi
    else
        echo "❌ Request failed"
        echo "$response_body"
        exit 1
    fi
}

# Show usage
show_usage() {
    cat <<EOF
🔧 New Relic Tracing AWS - API Gateway Caller

Usage:
    $0 [message] [additional_json_data]

Examples:
    $0
    $0 "Hello World"
    $0 "Test Message" '{"userId": "123", "priority": "high"}'
    $0 "Custom Test" '{"environment": "prod", "version": "1.2.3"}'

Environment:
    Reads configuration from .env file
    API_GATEWAY_URL - API Gateway endpoint URL
    NEW_RELIC_LICENSE_KEY - New Relic license key

Requirements:
    - curl (for HTTP requests)
    - jq (for JSON formatting, optional)
    - .env file with proper configuration

EOF
}

# Main execution
main() {
    echo "🌟 New Relic Distributed Tracing - Shell Client"
    echo "=============================================="
    
    # Check for help
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    # Check requirements
    if ! command -v curl &> /dev/null; then
        echo "❌ curl is required but not installed"
        exit 1
    fi
    
    # Load environment and get API URL
    load_env
    get_api_url
    
    # Send request
    local message="${1:-}"
    local additional_data="${2:-{}}"
    
    send_request "$message" "$additional_data"
    
    echo ""
    echo "🎉 Request completed successfully!"
}

# Run main function with all arguments
main "$@"