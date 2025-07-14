require('newrelic');

exports.handler = async (event, lambdaContext) => {
  console.log('Step Function Lambda 2 - Event:', JSON.stringify(event, null, 2));
  
  try {
    const newrelic = require('newrelic');
    
    // Set custom transaction name for New Relic
    newrelic.setTransactionName('Step Function Lambda2', 'Process Final Data');
    
    console.log('New Relic agent state:', newrelic.agent ? 'LOADED' : 'NOT_LOADED');
    
    // Accept distributed trace headers from Lambda1
    if (event.newRelicDistributedTraceHeaders) {
      console.log('Accepting distributed trace headers from Lambda1:', event.newRelicDistributedTraceHeaders);
      newrelic.acceptDistributedTraceHeaders('Other', event.newRelicDistributedTraceHeaders);
    }
    
    // New Relic distributed tracing
    const traceMetadata = newrelic.getTraceMetadata();
    const traceId = traceMetadata.traceId;
    const spanId = traceMetadata.spanId;
    
    console.log(`Lambda2 - Current Trace ID: ${traceId}, Span ID: ${spanId}`);
    console.log(`Lambda2 - Parent from Lambda1: ${event.lambda1Result?.traceId}`);

    await new Promise(resolve => setTimeout(resolve, 200));
    
    const finalResult = {
      ...event,
      lambda2Result: {
        processed: true,
        timestamp: new Date().toISOString(),
        processingTime: 200,
        traceId: traceId,
        spanId: spanId
      },
      finalStatus: 'completed',
      totalProcessingTime: (event.lambda1Result?.processingTime || 0) + 200,
      traceChain: {
        original: event.parentTraceId,
        lambda1: event.lambda1Result?.traceId,
        lambda2: traceId
      }
    };
    
    // Add custom attributes to New Relic
    newrelic.addCustomAttributes({
      'aws.lambda.function_name': lambdaContext.functionName,
      'aws.lambda.invocation_id': lambdaContext.awsRequestId,
      'parent.trace_id': event.lambda1Result?.traceId || 'unknown',
      'parent.span_id': event.lambda1Result?.spanId || 'unknown',
      'step.function': 'lambda2',
      'service.name': 'step-function-lambda2',
      'service.version': '1.0.0',
      'trace_id': traceId || 'unknown',
      'final.status': 'completed',
      'total.processing_time': finalResult.totalProcessingTime
    });

    console.log('Lambda2 - Final processing completed');
    console.log('Trace chain:', finalResult.traceChain);
    
    return finalResult;
    
  } catch (error) {
    console.error('Error in Step Function Lambda 2:', error);
    
    const newrelic = require('newrelic');
    newrelic.noticeError(error);
    
    throw error;
  }
};