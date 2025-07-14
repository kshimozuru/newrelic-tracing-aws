exports.config = {
  app_name: [process.env.NEW_RELIC_APP_NAME || 'newrelic-tracing-shell-client'],
  license_key: process.env.NEW_RELIC_LICENSE_KEY,
  logging: {
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
  },
  transaction_tracer: {
    enabled: true
  },
  slow_sql: {
    enabled: true
  }
};