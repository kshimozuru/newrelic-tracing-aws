require('newrelic');
const AWS = require('aws-sdk');

const batch = new AWS.Batch();

exports.handler = async (event, lambdaContext) => {
  console.log('SQS Processor - Event:', JSON.stringify(event, null, 2));
  
  try {
    const newrelic = require('newrelic');
    
    // Set custom transaction name for New Relic
    newrelic.setTransactionName('SQS Processor', 'Process Message');
    
    console.log('New Relic agent state:', newrelic.agent ? 'LOADED' : 'NOT_LOADED');
    
    // New Relic distributed tracing
    const traceMetadata = newrelic.getTraceMetadata();
    const traceId = traceMetadata.traceId;
    const spanId = traceMetadata.spanId;
    
    console.log(`New Relic Trace ID: ${traceId}, Span ID: ${spanId}`);
    
    for (const record of event.Records) {
      try {
        const messageBody = JSON.parse(record.body);
        console.log('Processing message:', JSON.stringify(messageBody, null, 2));
        
        // Accept distributed trace headers from API Gateway
        if (messageBody.newRelicDistributedTraceHeaders) {
          console.log('Accepting distributed trace headers from API Gateway:', messageBody.newRelicDistributedTraceHeaders);
          newrelic.acceptDistributedTraceHeaders('Other', messageBody.newRelicDistributedTraceHeaders);
        } else if (record.messageAttributes && record.messageAttributes.newrelic) {
          const headers = JSON.parse(record.messageAttributes.newrelic.stringValue);
          console.log('Accepting distributed trace headers from SQS attributes:', headers);
          newrelic.acceptDistributedTraceHeaders('Other', headers);
        }
        
        // Refresh trace metadata after accepting headers
        const updatedTraceMetadata = newrelic.getTraceMetadata();
        const updatedTraceId = updatedTraceMetadata.traceId;
        const updatedSpanId = updatedTraceMetadata.spanId;
        
        console.log(`Current Trace ID: ${updatedTraceId}, Span ID: ${updatedSpanId}`);
        console.log(`Parent Trace ID: ${messageBody.traceId}, Parent Span ID: ${messageBody.spanId}`);

        // Create distributed trace headers for Batch job
        const distributedTraceHeaders = {};
        newrelic.insertDistributedTraceHeaders(distributedTraceHeaders);
        console.log('Created distributed trace headers for Batch job:', distributedTraceHeaders);

        const jobParameters = {
          traceId: updatedTraceId || 'unknown',
          spanId: updatedSpanId || 'unknown',
          parentTraceId: messageBody.traceId,
          parentSpanId: messageBody.spanId,
          originalMessage: messageBody,
          timestamp: new Date().toISOString(),
          source: 'sqs-processor',
          // Add New Relic distributed trace information
          newRelicDistributedTraceHeaders: distributedTraceHeaders,
          newRelicTraceId: updatedTraceId
        };

        const batchParams = {
          jobName: `trace-job-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
          jobQueue: process.env.BATCH_JOB_QUEUE,
          jobDefinition: process.env.BATCH_JOB_DEFINITION,
          parameters: {
            jobData: JSON.stringify(jobParameters)
          }
        };

        console.log('Submitting Batch job:', JSON.stringify(batchParams, null, 2));
        
        const batchResult = await batch.submitJob(batchParams).promise();
        
        // Add custom attributes to New Relic
        newrelic.addCustomAttributes({
          'sqs.message_id': record.messageId,
          'batch.job_id': batchResult.jobId,
          'batch.job_name': batchResult.jobName,
          'batch.queue': process.env.BATCH_JOB_QUEUE,
          'parent_trace_id': messageBody.traceId || 'unknown',
          'trace_id': updatedTraceId || 'unknown',
          'service.name': 'sqs-processor',
          'service.version': '1.0.0'
        });

        console.log('Batch job submitted:', batchResult.jobId);
        
      } catch (error) {
        console.error('Error processing SQS message:', error);
        newrelic.noticeError(error);
        throw error;
      }
    }
    
    return { statusCode: 200 };
  } catch (error) {
    console.error('Error in SQS processor:', error);
    
    const newrelic = require('newrelic');
    newrelic.noticeError(error);
    
    return { statusCode: 500 };
  }
};