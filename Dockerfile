FROM grafana/grafana:11.6.3

ENV GF_PATHS_PROVISIONING=/etc/grafana/provisioning \
    GF_USERS_ALLOW_SIGN_UP=false \
    GF_AUTH_ANONYMOUS_ENABLED=false \
    GF_ANALYTICS_REPORTING_ENABLED=false \
    GF_ANALYTICS_CHECK_FOR_UPDATES=false

COPY --chown=472:472 grafana/provisioning /etc/grafana/provisioning
COPY --chown=472:472 grafana/dashboards /etc/grafana/dashboards
