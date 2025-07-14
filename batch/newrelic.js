'use strict'

/**
 * New Relic agent configuration for AWS Batch job
 */
exports.config = {
  app_name: [process.env.NEW_RELIC_APP_NAME || 'newrelic-tracing-batch-job'],
  license_key: process.env.NEW_RELIC_LICENSE_KEY,
  logging: {
    level: 'info',
    filepath: 'stdout'
  },
  distributed_tracing: {
    enabled: true
  },
  attributes: {
    enabled: true,
    include: [
      'request.headers.*',
      'request.parameters.*',
      'response.headers.*'
    ]
  },
  error_collector: {
    enabled: true,
    capture_events: true
  },
  transaction_tracer: {
    enabled: true,
    record_sql: 'obfuscated'
  },
  slow_sql: {
    enabled: true
  },
  application_logging: {
    enabled: true,
    forwarding: {
      enabled: true
    },
    metrics: {
      enabled: true
    },
    local_decorating: {
      enabled: true
    }
  },
  // ECS/Container specific settings
  utilization: {
    detect_aws: true,
    detect_docker: true
  },
  // Custom attributes for better entity identification
  labels: {
    'service.name': 'batch-job',
    'service.version': '1.0.0',
    'environment': 'demo'
  }
}