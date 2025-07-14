#!/bin/bash

# TraceID Verification Script for New Relic UI Matching
# This script generates detailed TraceID information for manual verification

set -e

# Load environment
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

# Add Go bin to PATH for otel-cli
export PATH=$PATH:~/go/bin

echo "🔍 New Relic TraceID Verification Tool"
echo "======================================"
echo ""

# Generate multiple test traces with different methods
generate_verification_traces() {
    echo "📋 Generating verification traces with detailed TraceID information..."
    echo ""
    
    # Test 1: OpenTelemetry with custom TraceID
    local custom_trace_id="deadbeef12345678abcdef0987654321"
    echo "🧪 Test 1: Custom TraceID Test"
    echo "   Custom TraceID: $custom_trace_id"
    echo "   Service Name: newrelic-traceid-verification"
    echo "   Operation: custom-traceid-test"
    echo ""
    
    otel-cli span \
        --name "custom-traceid-test" \
        --service "newrelic-traceid-verification" \
        --force-trace-id "$custom_trace_id" \
        --endpoint "https://otlp.nr-data.net/v1/traces" \
        --protocol "http/protobuf" \
        --otlp-headers "api-key=$NEW_RELIC_LICENSE_KEY" \
        --attrs "test.type=traceid-verification,test.custom=true,verification.traceid=$custom_trace_id" \
        --tp-print \
        --verbose \
        -- echo "Custom TraceID test completed"
    
    echo ""
    echo "✅ Custom TraceID test sent to New Relic"
    echo "   Expected in New Relic UI: $custom_trace_id"
    echo ""
    
    # Test 2: Generated TraceID with timestamp
    local timestamp=$(date +%s)
    local timestamp_hex=$(printf "%08x" $timestamp)
    local random_hex=$(openssl rand -hex 12)
    local generated_trace_id="${timestamp_hex}${random_hex}"
    
    echo "🧪 Test 2: Generated TraceID Test"
    echo "   Timestamp: $timestamp"
    echo "   Timestamp (hex): $timestamp_hex"
    echo "   Random part: $random_hex"
    echo "   Full TraceID: $generated_trace_id"
    echo "   Service Name: newrelic-traceid-verification"
    echo "   Operation: generated-traceid-test"
    echo ""
    
    otel-cli span \
        --name "generated-traceid-test" \
        --service "newrelic-traceid-verification" \
        --force-trace-id "$generated_trace_id" \
        --endpoint "https://otlp.nr-data.net/v1/traces" \
        --protocol "http/protobuf" \
        --otlp-headers "api-key=$NEW_RELIC_LICENSE_KEY" \
        --attrs "test.type=traceid-verification,test.generated=true,verification.traceid=$generated_trace_id,verification.timestamp=$timestamp" \
        --tp-print \
        --verbose \
        -- echo "Generated TraceID test completed"
    
    echo ""
    echo "✅ Generated TraceID test sent to New Relic"
    echo "   Expected in New Relic UI: $generated_trace_id"
    echo ""
    
    # Test 3: API Gateway call with TraceID
    echo "🧪 Test 3: API Gateway Call with TraceID"
    local api_trace_id=$(openssl rand -hex 16)
    echo "   API Call TraceID: $api_trace_id"
    echo "   Service Name: newrelic-traceid-verification"
    echo "   Operation: api-gateway-traceid-test"
    echo ""
    
    # Get API URL
    local api_url
    if [ -d "terraform" ] && command -v terraform &> /dev/null; then
        cd terraform
        api_url=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
        cd ..
    fi
    api_url="${api_url:-$API_GATEWAY_URL}"
    
    if [ -n "$api_url" ]; then
        # Create JSON payload with TraceID
        local json_payload=$(cat <<EOF
{
    "message": "TraceID Verification Test",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "source": "traceid-verification-script",
    "traceId": "$api_trace_id",
    "verification": {
        "test": "api-gateway-traceid",
        "expectedTraceId": "$api_trace_id"
    }
}
EOF
)
        
        echo "   API URL: $api_url"
        echo "   Payload TraceID: $api_trace_id"
        echo ""
        
        # Send request with OpenTelemetry span
        otel-cli span \
            --name "api-gateway-traceid-test" \
            --service "newrelic-traceid-verification" \
            --force-trace-id "$api_trace_id" \
            --endpoint "https://otlp.nr-data.net/v1/traces" \
            --protocol "http/protobuf" \
            --otlp-headers "api-key=$NEW_RELIC_LICENSE_KEY" \
            --attrs "test.type=api-gateway-traceid,verification.traceid=$api_trace_id,http.url=$api_url" \
            --tp-print \
            --verbose \
            -- curl -s -X POST \
                -H "Content-Type: application/json" \
                -H "User-Agent: TraceID-Verification/1.0" \
                -H "X-Trace-Id: $api_trace_id" \
                -H "traceparent: 00-${api_trace_id}-$(openssl rand -hex 8)-01" \
                -d "$json_payload" \
                "$api_url"
        
        echo ""
        echo "✅ API Gateway TraceID test completed"
        echo "   Expected in New Relic UI: $api_trace_id"
    else
        echo "   ⚠️  API Gateway URL not found, skipping API test"
    fi
    
    echo ""
}

# Summary information
show_verification_summary() {
    echo "📋 New Relic UI Verification Summary"
    echo "===================================="
    echo ""
    echo "🔍 Manual Verification Steps:"
    echo "1. Open New Relic One UI"
    echo "2. Navigate to APM & Services"
    echo "3. Look for service: 'newrelic-traceid-verification'"
    echo "4. Check Distributed Tracing section"
    echo "5. Search for the following TraceIDs:"
    echo ""
    echo "   📌 Custom TraceID: deadbeef12345678abcdef0987654321"
    echo "   📌 Generated TraceID: Check the output above"
    echo "   📌 API Gateway TraceID: Check the output above"
    echo ""
    echo "🎯 What to verify:"
    echo "   ✅ TraceID in New Relic UI matches exactly with shell output"
    echo "   ✅ Service name appears as 'newrelic-traceid-verification'"
    echo "   ✅ Operation names match (custom-traceid-test, etc.)"
    echo "   ✅ Custom attributes are visible in trace details"
    echo ""
    echo "⏰ Note: It may take 1-2 minutes for traces to appear in New Relic UI"
    echo ""
}

# Main execution
main() {
    echo "Starting TraceID verification process..."
    echo ""
    
    # Check dependencies
    if ! command -v otel-cli &> /dev/null; then
        echo "❌ otel-cli not found. Please install it:"
        echo "   go install github.com/equinix-labs/otel-cli@latest"
        exit 1
    fi
    
    if [ -z "$NEW_RELIC_LICENSE_KEY" ]; then
        echo "❌ NEW_RELIC_LICENSE_KEY not found in environment"
        exit 1
    fi
    
    generate_verification_traces
    show_verification_summary
}

# Run main function
main "$@"