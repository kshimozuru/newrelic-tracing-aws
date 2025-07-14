const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const serviceName = process.env.NEW_RELIC_APP_NAME || 'newrelic-tracing-service';

const traceExporter = new OTLPTraceExporter({
  url: 'https://otlp.nr-data.net/v1/traces',
  headers: {
    'api-key': process.env.NEW_RELIC_LICENSE_KEY,
  },
});

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: serviceName,
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
  }),
  traceExporter,
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-aws-lambda': {
      disableAwsContextPropagation: false,
    },
    '@opentelemetry/instrumentation-aws-sdk': {
      suppressInternalInstrumentation: false,
    },
  })],
});

module.exports = sdk;