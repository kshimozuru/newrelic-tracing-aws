#!/usr/bin/env node

require('dotenv').config({ path: '../.env' });
require('newrelic');
const { program } = require('commander');
const axios = require('axios');
const { trace, context, propagation } = require('@opentelemetry/api');
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'newrelic-tracing-cli',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
  }),
  instrumentations: [getNodeAutoInstrumentations()]
});

sdk.start();

program
  .name('trace-demo')
  .description('New Relic distributed tracing demo CLI')
  .version('1.0.0');

program
  .command('send')
  .description('Send a traced request through the AWS services')
  .requiredOption('-u, --url <url>', 'API Gateway URL')
  .option('-m, --message <message>', 'Message to send', 'Hello from CLI')
  .option('-d, --data <data>', 'Additional JSON data to send')
  .action(async (options) => {
    const tracer = trace.getTracer('cli-tracer');
    
    await tracer.startActiveSpan('cli-request', async (span) => {
      try {
        const traceId = span.spanContext().traceId;
        const spanId = span.spanContext().spanId;
        
        console.log(`Starting traced request...`);
        console.log(`CLI Trace ID: ${traceId}`);
        console.log(`CLI Span ID: ${spanId}`);
        
        span.setAttributes({
          'service.name': 'cli-client',
          'http.method': 'POST',
          'http.url': options.url,
          'cli.message': options.message
        });

        let requestData = {
          message: options.message,
          timestamp: new Date().toISOString(),
          source: 'cli'
        };

        if (options.data) {
          try {
            const additionalData = JSON.parse(options.data);
            requestData = { ...requestData, ...additionalData };
          } catch (e) {
            console.warn('Invalid JSON data provided, ignoring:', options.data);
          }
        }

        const carrier = {};
        propagation.inject(context.active(), carrier);
        
        console.log('Sending request with trace context...');
        console.log('Request data:', JSON.stringify(requestData, null, 2));
        
        const response = await axios.post(options.url, requestData, {
          headers: {
            'Content-Type': 'application/json',
            ...carrier
          },
          timeout: 30000
        });

        span.setAttributes({
          'http.status_code': response.status,
          'response.trace_id': response.data.traceId
        });

        console.log('Response received:');
        console.log(`Status: ${response.status}`);
        console.log(`Response:`, JSON.stringify(response.data, null, 2));
        
        if (response.data.traceId) {
          console.log(`\nTrace propagation successful!`);
          console.log(`CLI Trace ID: ${traceId}`);
          console.log(`API Gateway Trace ID: ${response.data.traceId}`);
          console.log(`\nCheck New Relic for distributed trace visualization.`);
        }
        
      } catch (error) {
        console.error('Error sending request:', error.message);
        if (error.response) {
          console.error('Response status:', error.response.status);
          console.error('Response data:', error.response.data);
        }
        span.recordException(error);
        span.setStatus({ code: 2, message: error.message });
        process.exit(1);
      }
    });
  });

program
  .command('test')
  .description('Test the CLI tracing setup')
  .action(async () => {
    const tracer = trace.getTracer('cli-tracer');
    
    await tracer.startActiveSpan('cli-test', async (span) => {
      const traceId = span.spanContext().traceId;
      const spanId = span.spanContext().spanId;
      
      console.log('CLI Tracing Test');
      console.log(`Trace ID: ${traceId}`);
      console.log(`Span ID: ${spanId}`);
      console.log('OpenTelemetry and New Relic integration working!');
      
      span.setAttributes({
        'test.type': 'cli-tracing',
        'test.status': 'success'
      });
    });
  });

program.parse();