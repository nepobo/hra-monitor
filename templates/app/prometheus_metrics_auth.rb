# frozen_string_literal: true

# Protects GET /metrics with a bearer token (and optional IP allow-list).
# In development the endpoint is open when PROMETHEUS_METRICS_TOKEN is unset.
module PrometheusMetrics
  class Auth
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless metrics_path?(env)

      token = ENV["PROMETHEUS_METRICS_TOKEN"].to_s
      if token.empty?
        return @app.call(env) unless defined?(Rails) && Rails.env.production?

        return unauthorized("metrics token is not configured\n")
      end

      provided = env["HTTP_AUTHORIZATION"].to_s
      return unauthorized("Unauthorized\n") unless provided == "Bearer #{token}"

      allow = ENV["PROMETHEUS_METRICS_ALLOW_IPS"].to_s.split(",").map(&:strip).reject(&:empty?)
      if allow.any?
        ip = forwarded_ip(env)
        return [403, { "Content-Type" => "text/plain" }, ["Forbidden\n"]] unless allow.include?(ip)
      end

      @app.call(env)
    end

    private

    def metrics_path?(env)
      env["PATH_INFO"].to_s.chomp("/") == "/metrics"
    end

    def forwarded_ip(env)
      env["HTTP_X_FORWARDED_FOR"]&.split(",")&.first&.strip || env["REMOTE_ADDR"]
    end

    def unauthorized(body)
      [401, { "Content-Type" => "text/plain", "WWW-Authenticate" => "Bearer" }, [body]]
    end
  end
end
