require('newrelic');
const AWS = require('aws-sdk');

const stepFunctions = new AWS.StepFunctions();

async function main() {
  console.log('Batch Job - Starting execution');
  
  const newrelic = require('newrelic');
  
  return await newrelic.startWebTransaction('batch-job-processing', async () => {
    try {
      // Set custom transaction name for New Relic
      newrelic.setTransactionName('Batch Job', 'Process Data');
      
      console.log('New Relic agent state:', newrelic.agent ? 'LOADED' : 'NOT_LOADED');
      
      const jobData = JSON.parse(process.env.AWS_BATCH_JOB_PARAMETERS || '{}').jobData;
      const parsedJobData = JSON.parse(jobData || '{}');
      
      console.log('Batch Job - Job Data:', JSON.stringify(parsedJobData, null, 2));
      
      // Accept distributed trace headers from SQS processor
      if (parsedJobData.newRelicDistributedTraceHeaders) {
        console.log('Accepting distributed trace headers from SQS processor:', parsedJobData.newRelicDistributedTraceHeaders);
        newrelic.acceptDistributedTraceHeaders('Other', parsedJobData.newRelicDistributedTraceHeaders);
      }
      
      if (parsedJobData.newRelicTraceId) {
        console.log('Received trace ID from parent:', parsedJobData.newRelicTraceId);
      }
      
      // New Relic distributed tracing
      const traceMetadata = newrelic.getTraceMetadata();
      const traceId = traceMetadata.traceId;
      const spanId = traceMetadata.spanId;
      
      console.log(`New Relic Trace ID: ${traceId}, Span ID: ${spanId}`);
    
      console.log(`Batch - Current Trace ID: ${traceId}, Span ID: ${spanId}`);
      console.log(`Batch - Parent Trace ID: ${parsedJobData.parentTraceId}, Parent Span ID: ${parsedJobData.parentSpanId}`);

      console.log('Batch Job - Performing intensive computation...');
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      const computationResult = {
        result: Math.random() * 1000,
        computation: 'matrix_multiplication',
        duration: 3000,
        timestamp: new Date().toISOString()
      };
      
      console.log('Batch Job - Computation completed:', computationResult);

      // Create distributed trace headers for Step Functions
      const distributedTraceHeaders = {};
      newrelic.insertDistributedTraceHeaders(distributedTraceHeaders);
      console.log('Created distributed trace headers for Step Functions:', distributedTraceHeaders);

      const stepFunctionInput = {
        ...parsedJobData,
        batchJobResult: {
          ...computationResult,
          traceId: traceId || 'unknown',
          spanId: spanId || 'unknown'
        },
        parentTraceId: parsedJobData.parentTraceId,
        parentSpanId: parsedJobData.parentSpanId,
        // Add New Relic distributed trace information
        newRelicDistributedTraceHeaders: distributedTraceHeaders,
        newRelicTraceId: traceId
      };

      const stepFunctionParams = {
        stateMachineArn: process.env.STATE_MACHINE_ARN,
        input: JSON.stringify(stepFunctionInput),
        name: `execution-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
      };

      console.log('Batch Job - Starting Step Functions execution:', JSON.stringify(stepFunctionParams, null, 2));
      
      const stepFunctionResult = await stepFunctions.startExecution(stepFunctionParams).promise();
      
      // Add custom attributes to New Relic
      newrelic.addCustomAttributes({
        'batch.job_name': process.env.AWS_BATCH_JOB_NAME || 'unknown',
        'batch.job_id': process.env.AWS_BATCH_JOB_ID || 'unknown',
        'parent_trace_id': parsedJobData.parentTraceId || 'unknown',
        'parent_span_id': parsedJobData.parentSpanId || 'unknown',
        'step_functions.execution_arn': stepFunctionResult.executionArn,
        'step_functions.start_date': stepFunctionResult.startDate.toISOString(),
        'batch.computation_result': computationResult.result,
        'trace_id': traceId || 'unknown',
        'service.name': 'batch-job',
        'service.version': '1.0.0'
      });

      console.log('Batch Job - Step Functions execution started:', stepFunctionResult.executionArn);
      console.log('Batch Job - Execution completed successfully');
      
      return {
        success: true,
        traceId: traceId,
        executionArn: stepFunctionResult.executionArn
      };
      
    } catch (error) {
      console.error('Error in Batch job:', error);
      newrelic.noticeError(error);
      throw error;
    }
  });
}

main().catch(error => {
  console.error('Fatal error in Batch job:', error);
  process.exit(1);
});