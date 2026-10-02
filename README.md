# Monitoring stack for HRA Rails apps: Prometheus, Grafana, Alertmanager, Blackbox.

All monitoring services run as **Docker containers** and are deployed with **Kamal**. Prometheus pulls metrics over the public internet (no VPC). Targets must be stable URLs/ports, protected by a bearer token and a DigitalOcean Cloud Firewall.

## Deploy the monitor (step 1)

1. Dedicated droplet with SSH as `root`, ports **22/80/443** open. Do **not** expose 9090 or 9093.
2. DNS A record `GRAFANA_HOST` → that droplet (Let's Encrypt via kamal-proxy).
3. Copy env and fill real values:

```bash
cp .env.example .env
```

Required: `MONITOR_HOST`, `GRAFANA_HOST`, `KAMAL_REGISTRY_TOKEN`, `GRAFANA_ADMIN_PASSWORD`, `PROMETHEUS_METRICS_TOKEN`.

4. From this repo (Ruby on the laptop is optional — `bin/kamal` uses Docker if needed):

```bash
bin/setup
```

That renders scrape configs, builds/pushes the Grafana image, deploys it, and boots Prometheus, Alertmanager, and Blackbox.

5. Open `https://$GRAFANA_HOST` (user `admin`). Accessories: `bin/kamal accessory details prometheus`.

Later config changes: `bin/apply`. Dashboard changes: `bin/kamal deploy`.

hra-ocr scrape targets stay **down** until step 2 (app instrumentation). That is expected.

Optional alerts: uncomment email/Telegram in `prometheus/alertmanager.yml`, then `bin/kamal accessory reboot alertmanager`.

## Adding an application (step 2)

```bash
bin/add-app --name chatgrid \
  --health-url https://chatgrid.ru/up \
  --scrape web=https://chatgrid.ru/metrics \
  --node chatgrid.ru
```

Copy `templates/app/` into the Rails app, deploy it with Kamal, boot `node-exporter` once per host, then `bin/apply`.

Web scrape targets should be HTTPS through kamal-proxy. Sidekiq publishes host ports `9394-9396`.

## Firewall on app hosts

Allow inbound **only from `MONITOR_HOST`**:

- `9100/tcp` — node-exporter
- `9394-9396/tcp` — Sidekiq metrics

## Layout

- `apps.yml` — registry of applications
- `bin/setup` — first deploy of the monitor
- `bin/add-app` / `bin/render` / `bin/apply`
- `bin/kamal` — Kamal (local bundle or Docker CLI image)
- `templates/app/` — files to copy into each Rails app
- `grafana/dashboards/` — Uptime, Rails, Sidekiq, Nodes
