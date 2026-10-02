# frozen_string_literal: true

require Rails.root.join("lib/prometheus_metrics/auth")
require Rails.root.join("lib/prometheus_metrics_server")

Rails.application.config.middleware.insert_before 0, PrometheusMetrics::Auth

Sidekiq.configure_server do |config|
  config.on(:startup) do
    PrometheusMetricsServer.start!(
      port: Integer(ENV.fetch("PROMETHEUS_METRICS_PORT", "9394")),
      bind: ENV.fetch("PROMETHEUS_METRICS_BIND", "0.0.0.0"),
      token: ENV["PROMETHEUS_METRICS_TOKEN"]
    )
  end
end
