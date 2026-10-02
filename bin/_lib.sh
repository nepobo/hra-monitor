#!/usr/bin/env bash
# Shared helpers for running Ruby/Kamal without a host Ruby install.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

KAMAL_IMAGE="${KAMAL_IMAGE:-hra-monitor-kamal:latest}"

load_dotenv() {
  local file="$ROOT/.env"
  [ -f "$file" ] || return 0

  local line key value
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
      fi
      export "${key}=${value}"
    else
      echo "Skipping invalid .env line (use Latin KEY=value): ${line%%=*}" >&2
    fi
  done < "$file"
}

require_deploy_env() {
  load_dotenv

  if [ ! -f "$ROOT/.env" ]; then
    echo "Missing .env — copy .env.example and fill MONITOR_HOST, GRAFANA_HOST, and secrets." >&2
    exit 1
  fi

  local missing=()
  [ -n "${MONITOR_HOST:-}" ] && [ "${MONITOR_HOST}" != "CHANGE_ME" ] || missing+=("MONITOR_HOST")
  [ -n "${GRAFANA_HOST:-}" ] && [ "${GRAFANA_HOST}" != "grafana.example.com" ] || missing+=("GRAFANA_HOST")
  [ -n "${KAMAL_REGISTRY_TOKEN:-}" ] || missing+=("KAMAL_REGISTRY_TOKEN")
  [ -n "${GRAFANA_ADMIN_PASSWORD:-}" ] || missing+=("GRAFANA_ADMIN_PASSWORD")
  [ -n "${PROMETHEUS_METRICS_TOKEN:-}" ] || missing+=("PROMETHEUS_METRICS_TOKEN")

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Set these in .env before deploy: ${missing[*]}" >&2
    exit 1
  fi
}

run_ruby() {
  if command -v ruby >/dev/null 2>&1 && ruby -e "require 'yaml'" >/dev/null 2>&1; then
    ruby "$@"
    return
  fi

  docker run --rm \
    -v "$ROOT:/app" \
    -w /app \
    ruby:3.4.1-slim \
    ruby "$@"
}

ensure_kamal_image() {
  local need_build=0
  if ! docker image inspect "$KAMAL_IMAGE" >/dev/null 2>&1; then
    need_build=1
  elif ! docker run --rm --entrypoint docker "$KAMAL_IMAGE" buildx version >/dev/null 2>&1; then
    echo "Kamal CLI image is missing docker buildx, rebuilding…"
    need_build=1
  fi

  if [ "$need_build" -eq 1 ]; then
    echo "Building Kamal CLI image ($KAMAL_IMAGE)…"
    docker build -f Dockerfile.kamal -t "$KAMAL_IMAGE" "$ROOT"
  fi
}

run_kamal() {
  load_dotenv

  if command -v bundle >/dev/null 2>&1 && bundle exec kamal version >/dev/null 2>&1; then
    bundle exec kamal "$@"
    return
  fi

  ensure_kamal_image

  local docker_args=(
    --rm
    -v "$ROOT:/workdir"
    -v /var/run/docker.sock:/var/run/docker.sock
    -v "$HOME/.ssh:/root/.ssh"
    -w /workdir
    -e HOME=/root
  )

  if [ -f "$ROOT/.env" ]; then
    docker_args+=(--env-file "$ROOT/.env")
  fi

  # Repo is owned by the host user; Kamal runs as root and Git 2.35+
  # refuses to read .git without this (needed for image version = commit).
  docker_args+=(
    -e GIT_CONFIG_COUNT=1
    -e GIT_CONFIG_KEY_0=safe.directory
    -e GIT_CONFIG_VALUE_0=/workdir
  )

  if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK}" ]; then
    docker_args+=(-e SSH_AUTH_SOCK=/ssh-agent -v "$SSH_AUTH_SOCK:/ssh-agent")
  fi

  if [ -t 0 ] && [ -t 1 ]; then
    docker_args+=(-it)
  fi

  docker run "${docker_args[@]}" "$KAMAL_IMAGE" "$@"
}
