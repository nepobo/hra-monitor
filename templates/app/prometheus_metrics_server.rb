# frozen_string_literal: true

require "rack/handler/webrick"
require "webrick"

# Standalone /metrics server for Sidekiq processes (they have no Puma).
module PrometheusMetricsServer
  module_function

  def start!(port:, bind:, token:)
    return if @started

    @started = true
    app = PrometheusMetrics::Auth.new(Yabeda::Prometheus::Exporter)

    Thread.new do
      Rack::Handler::WEBrick.run(
        app,
        Host: bind,
        Port: port,
        Logger: WEBrick::Log.new($stdout, WEBrick::Log::WARN),
        AccessLog: []
      )
    end
  end
end
