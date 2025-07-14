require('newrelic');

exports.handler = async (event, lambdaContext) => {
  console.log('Step Function Lambda 1 - Event:', JSON.stringify(event, null, 2));
  
  try {
    const newrelic = require('newrelic');
    
    // Set custom transaction name for New Relic
    newrelic.setTransactionName('Step Function Lambda1', 'Process Data');
    
    console.log('New Relic agent state:', newrelic.agent ? 'LOADED' : 'NOT_LOADED');
    
    // Accept distributed trace headers from Batch job
    if (event.newRelicDistributedTraceHeaders) {
      console.log('Accepting distributed trace headers from Batch job:', event.newRelicDistributedTraceHeaders);
      newrelic.acceptDistributedTraceHeaders('Other', event.newRelicDistributedTraceHeaders);
    }
    
    // New Relic distributed tracing
    const traceMetadata = newrelic.getTraceMetadata();
    const traceId = traceMetadata.traceId;
    const spanId = traceMetadata.spanId;
    
    console.log(`Lambda1 - Current Trace ID: ${traceId}, Span ID: ${spanId}`);
    console.log(`Lambda1 - Parent Trace ID: ${event.parentTraceId}, Parent Span ID: ${event.parentSpanId}`);

    await new Promise(resolve => setTimeout(resolve, 100));
    
    const processedData = {
      ...event,
      lambda1Result: {
        processed: true,
        timestamp: new Date().toISOString(),
        processingTime: 100,
        traceId: traceId,
        spanId: spanId
      }
    };

    // Create distributed trace headers for Lambda2
    const distributedTraceHeaders = {};
    newrelic.insertDistributedTraceHeaders(distributedTraceHeaders);
    processedData.newRelicDistributedTraceHeaders = distributedTraceHeaders;
    
    // Add custom attributes to New Relic
    newrelic.addCustomAttributes({
      'aws.lambda.function_name': lambdaContext.functionName,
      'aws.lambda.invocation_id': lambdaContext.awsRequestId,
      'parent.trace_id': event.parentTraceId || 'unknown',
      'parent.span_id': event.parentSpanId || 'unknown',
      'step.function': 'lambda1',
      'service.name': 'step-function-lambda1',
      'service.version': '1.0.0',
      'trace_id': traceId || 'unknown'
    });

    console.log('Lambda1 - Processing completed');
    
    return processedData;
    
  } catch (error) {
    console.error('Error in Step Function Lambda 1:', error);
    
    const newrelic = require('newrelic');
    newrelic.noticeError(error);
    
    throw error;
  }
};