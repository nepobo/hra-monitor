#!/bin/sh
set -eu
echo -n "${PROMETHEUS_METRICS_TOKEN}" > /tmp/metrics_token
chmod 600 /tmp/metrics_token
exec /bin/prometheus "$@"
