#!/bin/bash

# New Relic Tracing AWS - OpenTelemetry Shell Client
# Uses otel-cli to send traces directly to New Relic via OpenTelemetry Protocol

set -e

# Add Go bin to PATH for otel-cli
export PATH=$PATH:~/go/bin

# OpenTelemetry Configuration for New Relic
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp.nr-data.net/v1/traces"
export OTEL_SERVICE_NAME="${NEW_RELIC_APP_NAME:-newrelic-tracing-otel-shell}"
export OTEL_RESOURCE_ATTRIBUTES="service.name=${OTEL_SERVICE_NAME},service.version=1.0.0"

echo "🌟 New Relic OpenTelemetry Shell Client"
echo "=============================================="

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

# Check dependencies
check_dependencies() {
    if ! command -v otel-cli &> /dev/null; then
        echo "❌ otel-cli not found. Please install it:"
        echo "   go install github.com/equinix-labs/otel-cli@latest"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        echo "❌ curl is required but not installed"
        exit 1
    fi
    
    echo "✅ Dependencies checked"
}

# Get API Gateway URL
get_api_url() {
    if [ -d "terraform" ] && command -v terraform &> /dev/null; then
        cd terraform
        API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
        cd ..
        if [ -n "$API_URL" ]; then
            echo "✅ API Gateway URL: $API_URL"
        else
            echo "❌ Could not get API Gateway URL from Terraform"
            API_URL="${API_GATEWAY_URL:-}"
        fi
    else
        echo "⚠️  Terraform not found, using URL from .env"
        API_URL="${API_GATEWAY_URL:-}"
    fi
    
    if [ -z "$API_URL" ]; then
        echo "❌ API Gateway URL not found"
        exit 1
    fi
}

# Generate W3C compatible trace ID
generate_trace_id() {
    local timestamp_hex=$(printf "%08x" $(date +%s))
    local random_hex=$(openssl rand -hex 12 2>/dev/null || dd if=/dev/urandom bs=12 count=1 2>/dev/null | xxd -p -c 12)
    echo "${timestamp_hex}${random_hex}" | head -c 32
}

# Send OpenTelemetry span to New Relic
send_otel_span() {
    local operation_name="$1"
    local message="$2"
    local additional_data="$3"
    local trace_id=$(generate_trace_id)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    echo "🚀 Creating OpenTelemetry span..."
    echo "📝 Operation: $operation_name"
    echo "📝 Message: $message"
    echo "🔍 Trace ID: $trace_id"
    echo "🏷️  Service: $OTEL_SERVICE_NAME"
    echo ""
    
    # Create span with otel-cli and send to New Relic
    otel-cli span \
        --name "$operation_name" \
        --service "$OTEL_SERVICE_NAME" \
        --force-trace-id "$trace_id" \
        --endpoint "$OTEL_EXPORTER_OTLP_ENDPOINT" \
        --otlp-headers "api-key=$NEW_RELIC_LICENSE_KEY" \
        --attrs "shell.message=$message,shell.timestamp=$timestamp,shell.source=otel-shell" \
        --verbose \
        -- echo "OpenTelemetry span sent to New Relic"
    
    echo "✅ OpenTelemetry span created and sent to New Relic"
    return 0
}

# Send HTTP request with trace context
send_api_request() {
    local message="$1"
    local additional_data="$2"
    local trace_id=$(generate_trace_id)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Create JSON payload
    local json_payload
    if [ "$additional_data" = "{}" ]; then
        json_payload=$(cat <<EOF
{
    "message": "$message",
    "timestamp": "$timestamp",
    "source": "otel-shell-client",
    "traceId": "$trace_id"
}
EOF
)
    else
        json_payload=$(cat <<EOF
{
    "message": "$message",
    "timestamp": "$timestamp",
    "source": "otel-shell-client",
    "traceId": "$trace_id",
    "additionalData": $additional_data
}
EOF
)
    fi
    
    echo "🌐 Sending HTTP request to API Gateway..."
    echo "🎯 URL: $API_URL"
    echo ""
    
    # Send OpenTelemetry span for the entire operation
    otel-cli span \
        --name "api-gateway-call" \
        --service "$OTEL_SERVICE_NAME" \
        --force-trace-id "$trace_id" \
        --endpoint "$OTEL_EXPORTER_OTLP_ENDPOINT" \
        --otlp-headers "api-key=$NEW_RELIC_LICENSE_KEY" \
        --attrs "http.method=POST,http.url=$API_URL,shell.message=$message" \
        --verbose \
        -- curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "User-Agent: NewRelic-OTEL-Shell/1.0" \
            -H "X-Trace-Id: $trace_id" \
            -H "traceparent: 00-${trace_id}-$(openssl rand -hex 8)-01" \
            -d "$json_payload" \
            "$API_URL"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo ""
        echo "✅ Request completed with OpenTelemetry tracing"
        echo "🔗 Trace ID: $trace_id"
        echo "🏷️  Service: $OTEL_SERVICE_NAME"
        echo "💡 Check New Relic APM for service: $OTEL_SERVICE_NAME"
    else
        echo "❌ Request failed"
        exit 1
    fi
}

# Test OpenTelemetry integration
test_otel_integration() {
    echo "🧪 Testing OpenTelemetry integration with New Relic..."
    echo "🏷️  Service Name: $OTEL_SERVICE_NAME"
    echo "🔗 New Relic Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
    echo ""
    
    # Send test span
    otel-cli span \
        --name "otel-integration-test" \
        --service "$OTEL_SERVICE_NAME" \
        --endpoint "$OTEL_EXPORTER_OTLP_ENDPOINT" \
        --protocol "http/protobuf" \
        --otlp-headers "api-key=$NEW_RELIC_LICENSE_KEY" \
        --attrs "test.type=integration,test.status=success,test.tool=otel-cli" \
        --verbose \
        -- echo "OpenTelemetry test span sent successfully"
    
    echo ""
    echo "✅ OpenTelemetry integration test completed"
    echo "💡 Check New Relic APM for service: $OTEL_SERVICE_NAME"
}

# Show usage
show_usage() {
    cat <<EOF
🔧 New Relic OpenTelemetry Shell Client

Usage:
    $0 [command] [options]

Commands:
    send <message> [additional_json_data]  - Send API request with OpenTelemetry tracing
    test                                   - Test OpenTelemetry integration
    span <operation> <message>             - Send standalone OpenTelemetry span

Examples:
    $0 send "Hello OpenTelemetry"
    $0 send "Test Message" '{"userId": "123", "priority": "high"}'
    $0 test
    $0 span "custom-operation" "Custom span test"

Environment:
    NEW_RELIC_LICENSE_KEY  - New Relic license key (required)
    NEW_RELIC_APP_NAME     - Service name for OpenTelemetry (optional)
    API_GATEWAY_URL        - API Gateway endpoint URL

Requirements:
    - otel-cli (go install github.com/equinix-labs/otel-cli@latest)
    - curl
    - openssl
    - .env file with proper configuration

EOF
}

# Main execution
main() {
    case "${1:-help}" in
        "send")
            echo "📡 OpenTelemetry API Gateway Call Mode"
            echo "======================================"
            load_env
            check_dependencies
            get_api_url
            local message="${2:-Hello from OpenTelemetry Shell}"
            local additional_data="${3:-{}}"
            send_api_request "$message" "$additional_data"
            ;;
        "test")
            echo "🧪 OpenTelemetry Integration Test Mode"
            echo "======================================"
            load_env
            check_dependencies
            test_otel_integration
            ;;
        "span")
            echo "📊 OpenTelemetry Span Mode"
            echo "========================="
            load_env
            check_dependencies
            local operation="${2:-custom-operation}"
            local message="${3:-Hello from OpenTelemetry}"
            send_otel_span "$operation" "$message"
            ;;
        "help"|"--help"|"-h"|"")
            show_usage
            ;;
        *)
            echo "❌ Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"