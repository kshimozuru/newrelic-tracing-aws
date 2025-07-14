#!/bin/bash

# Query New Relic for specific TraceIDs via NerdGraph API
# This helps verify if our TraceIDs are actually appearing in New Relic

set -e

# Load environment
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

echo "🔍 New Relic TraceID Query Tool"
echo "==============================="
echo ""

# Function to query New Relic for a specific TraceID
query_trace_id() {
    local trace_id="$1"
    local description="$2"
    
    echo "🔍 Querying TraceID: $trace_id ($description)"
    
    # NerdGraph query to search for the trace
    local query=$(cat <<EOF
{
  "query": "query(\$accountId: Int!) { 
    actor { 
      account(id: \$accountId) { 
        distributed_tracing { 
          trace(traceId: \"$trace_id\") { 
            id 
            timestamp 
            durationMs 
            spans { 
              id 
              name 
              operationName 
              attributes 
            } 
          } 
        } 
      } 
    } 
  }",
  "variables": {
    "accountId": $NEW_RELIC_ACCOUNT_ID
  }
}
EOF
)
    
    if [ -n "$NEW_RELIC_USER_KEY" ]; then
        echo "   Making API request to New Relic NerdGraph..."
        
        local response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "API-Key: $NEW_RELIC_USER_KEY" \
            -d "$query" \
            "https://api.newrelic.com/graphql")
        
        echo "   Response: $response"
        
        # Check if trace was found
        if echo "$response" | grep -q "\"trace\""; then
            echo "   ✅ TraceID found in New Relic!"
        else
            echo "   ❌ TraceID not found (may still be processing)"
        fi
    else
        echo "   ⚠️  NEW_RELIC_USER_KEY not set, skipping API query"
        echo "   💡 Set NEW_RELIC_USER_KEY in .env for API verification"
    fi
    
    echo ""
}

# Function to search for traces by service name
query_service_traces() {
    local service_name="$1"
    
    echo "🔍 Querying traces for service: $service_name"
    
    # NRQL query to find recent traces for the service
    local nrql_query="SELECT traceId, timestamp FROM Span WHERE service.name = '$service_name' SINCE 10 minutes ago LIMIT 10"
    
    local query=$(cat <<EOF
{
  "query": "query(\$accountId: Int!) { 
    actor { 
      account(id: \$accountId) { 
        nrql(query: \"$nrql_query\") { 
          results 
        } 
      } 
    } 
  }",
  "variables": {
    "accountId": $NEW_RELIC_ACCOUNT_ID
  }
}
EOF
)
    
    if [ -n "$NEW_RELIC_USER_KEY" ]; then
        echo "   Making NRQL query to New Relic..."
        
        local response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "API-Key: $NEW_RELIC_USER_KEY" \
            -d "$query" \
            "https://api.newrelic.com/graphql")
        
        echo "   NRQL Response: $response"
        
        # Extract TraceIDs from response
        if echo "$response" | grep -q "traceId"; then
            echo "   ✅ Service traces found!"
            echo "$response" | grep -o '"traceId":"[^"]*"' | head -5
        else
            echo "   ❌ No traces found for service (may still be processing)"
        fi
    else
        echo "   ⚠️  NEW_RELIC_USER_KEY not set, skipping NRQL query"
    fi
    
    echo ""
}

# Main execution
main() {
    echo "Starting New Relic TraceID verification via API..."
    echo ""
    
    if [ -z "$NEW_RELIC_LICENSE_KEY" ]; then
        echo "❌ NEW_RELIC_LICENSE_KEY not found in environment"
        exit 1
    fi
    
    # Query specific TraceIDs from our verification test
    echo "📋 Querying specific TraceIDs from verification test:"
    echo ""
    
    query_trace_id "deadbeef12345678abcdef0987654321" "Custom TraceID"
    query_trace_id "6874ab0d3798c44124dfe783832114a4" "Generated TraceID"
    query_trace_id "1329663bb5691f000e7a72996ca32f14" "API Gateway TraceID"
    
    # Query service for all traces
    echo "📋 Querying all traces for verification service:"
    echo ""
    query_service_traces "newrelic-traceid-verification"
    
    echo "📋 Manual UI Verification:"
    echo "=========================="
    echo ""
    echo "🌐 New Relic One UI URLs to check:"
    echo "   • APM & Services: https://one.newrelic.com/apm"
    echo "   • Distributed Tracing: https://one.newrelic.com/distributed-tracing"
    echo "   • Service: newrelic-traceid-verification"
    echo ""
    echo "🔍 TraceIDs to search for:"
    echo "   • deadbeef12345678abcdef0987654321"
    echo "   • 6874ab0d3798c44124dfe783832114a4"
    echo "   • 1329663bb5691f000e7a72996ca32f14"
    echo ""
    echo "⏰ Note: Traces may take 1-2 minutes to appear in the UI"
    echo ""
}

# Run main function
main "$@"