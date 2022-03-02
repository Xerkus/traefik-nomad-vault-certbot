#!/bin/bash

set -e

readonly SCRIPT_NAME="$(basename "$0")"

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function assert_is_installed {
  local -r name="$1"

  if [[ ! $(command -v "${name}") ]]; then
    log_error "The executable '$name' is required by this script but is not installed or not in the system's PATH."
    exit 1
  fi
}

function assert_not_empty {
  local readonly arg_name="$1"
  local readonly arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    exit 1
  fi
}

function run {
  assert_is_installed "vault"

  assert_not_empty 'VAULT_ADDR env variable' "$VAULT_ADDR"
  assert_not_empty 'VAULT_TOKEN env variable' "$VAULT_TOKEN"
  assert_not_empty 'RENEWED_LINEAGE env variable' "$RENEWED_LINEAGE"

  local cert_name=""
  cert_name=$(basename "$RENEWED_LINEAGE")

  log_info "Storing into vault updated certificate '${cert_name}' for domains ${RENEWED_DOMAINS}"
  vault kv put "secrets/acme/certs/$cert_name" \
    "cert=@${RENEWED_LINEAGE}/cert.pem" \
    "chain=@${RENEWED_LINEAGE}/chain.pem" \
    "fullchain=@${RENEWED_LINEAGE}/fullchain.pem" \
    "privkey=@${RENEWED_LINEAGE}/privkey.pem" \
    "renewal=@/etc/letsencrypt/renewal/${cert_name}.conf" \
    "domains=${RENEWED_DOMAINS}"
}

# certbot swallows hook output. Redirect it to docker out instead
run "$@" >/proc/1/fd/1 2>/proc/1/fd/2