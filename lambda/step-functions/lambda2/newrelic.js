exports.config = {
  app_name: [process.env.NEW_RELIC_APP_NAME || 'newrelic-tracing-step-function-lambda2'],
  license_key: process.env.NEW_RELIC_LICENSE_KEY,
  serverless_mode: {
    enabled: true
  },  logging: {
    level: 'info'
  },
  distributed_tracing: {
    enabled: true
  },
  application_logging: {
    enabled: true,
    forwarding: {
      enabled: true
    }
  }
};