# Adding __APP__ to monitoring

The registry entry is already in `apps.yml` (`env=__ENV__`). Finish the Rails app and firewall, then apply.

## 1. Instrument the Rails app

Copy from `templates/app/` into the application:

- Gemfile gems from `Gemfile.snippet`, then `bundle install`
- `lib/prometheus_metrics/auth.rb`
- `lib/prometheus_metrics_server.rb`
- `config/initializers/yabeda.rb`
- `plugin :yabeda` in `config/puma.rb`
- `mount Yabeda::Prometheus::Exporter => "/metrics"` in routes
- Safelist `/metrics` in Rack::Attack if the app throttles by IP

## 2. Kamal on the app

- Put `PROMETHEUS_METRICS_TOKEN` in `.kamal/secrets` (same value as hra-monitor)
- Add the token to `env.secret` in `config/deploy.yml`
- Publish Sidekiq metrics ports so they do not collide on a shared host
- Boot `node_exporter` accessory **once per host** (`kamal accessory boot node_exporter`)

See `templates/app/deploy.yml.snippet`.

## 3. Firewall (DigitalOcean Cloud Firewall, free)

Inbound, **only from the monitoring server IP**:

- TCP `9100` — node-exporter
- TCP `9394-9396` — Sidekiq metrics (HTTP + bearer token)

Do **not** open Prometheus or these ports to the world. Web `/metrics` stays on 443 and is protected by the bearer token.

## 4. Apply monitoring config

```bash
bin/apply
```

If Grafana dashboards changed:

```bash
bin/kamal deploy
```

## 5. Verify

- `curl -I https://<app>/metrics` → 401 without token
- `curl -H "Authorization: Bearer $PROMETHEUS_METRICS_TOKEN" https://<app>/metrics` → 200
- Grafana → HRA folder: Uptime, Rails / Puma, Sidekiq, Nodes
