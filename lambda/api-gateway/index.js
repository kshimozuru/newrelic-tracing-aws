require('newrelic');
const AWS = require('aws-sdk');

const sqs = new AWS.SQS();

exports.handler = async (event, lambdaContext) => {
  console.log('API Gateway Handler - Event:', JSON.stringify(event, null, 2));
  
  try {
    const newrelic = require('newrelic');
    
    // Set custom transaction name for New Relic
    newrelic.setTransactionName('API Gateway', 'Trace Request');
    
    console.log('New Relic agent state:', newrelic.agent ? 'LOADED' : 'NOT_LOADED');
    
    // New Relic distributed tracing
    const traceMetadata = newrelic.getTraceMetadata();
    const traceId = traceMetadata.traceId;
    const spanId = traceMetadata.spanId;
    
    console.log(`New Relic Trace ID: ${traceId}, Span ID: ${spanId}`);

    let body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch (e) {
      body = { message: event.body || 'No body provided' };
    }

    const messageBody = {
      ...body,
      traceId: traceId || 'unknown',
      spanId: spanId || 'unknown',
      timestamp: new Date().toISOString(),
      source: 'api-gateway',
      requestId: lambdaContext.awsRequestId
    };

    // Create New Relic distributed trace headers
    const distributedTraceHeaders = {};
    newrelic.insertDistributedTraceHeaders(distributedTraceHeaders);
    
    console.log('Created distributed trace headers:', distributedTraceHeaders);
    
    // Add New Relic trace information
    messageBody.newRelicTraceId = traceId;
    messageBody.newRelicSpanId = spanId;
    messageBody.newRelicDistributedTraceHeaders = distributedTraceHeaders;

    const params = {
      QueueUrl: process.env.SQS_QUEUE_URL,
      MessageBody: JSON.stringify(messageBody),
      MessageAttributes: {
        traceId: {
          DataType: 'String',
          StringValue: traceId || 'unknown'
        },
        spanId: {
          DataType: 'String',
          StringValue: spanId || 'unknown'
        },
        newrelic: {
          DataType: 'String',
          StringValue: JSON.stringify(distributedTraceHeaders)
        }
      }
    };

    console.log('Sending message to SQS:', JSON.stringify(params, null, 2));
    
    const result = await sqs.sendMessage(params).promise();
    
    // Add custom attributes to New Relic
    newrelic.addCustomAttributes({
      'sqs.message_id': result.MessageId,
      'sqs.queue_url': process.env.SQS_QUEUE_URL,
      'http.method': event.httpMethod,
      'http.path': event.path,
      'trace_id': traceId || 'unknown'
    });

    console.log('Message sent to SQS:', result.MessageId);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: 'Request processed successfully',
        traceId: traceId,
        messageId: result.MessageId,
        timestamp: new Date().toISOString()
      })
    };
  } catch (error) {
    console.error('Error in API Gateway handler:', error);
    
    const newrelic = require('newrelic');
    newrelic.noticeError(error);
    
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: 'Internal server error',
        message: error.message
      })
    };
  }
};