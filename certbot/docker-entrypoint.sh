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

function assert_not_empty {
  local readonly arg_name="$1"
  local readonly arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    exit 1
  fi
}

assert_not_empty 'AWS_ACCESS_KEY_ID env variable' "$AWS_ACCESS_KEY_ID"
assert_not_empty 'AWS_SECRET_ACCESS_KEY env variable' "$AWS_SECRET_ACCESS_KEY"
assert_not_empty 'VAULT_ADDR env variable' "$VAULT_ADDR"
assert_not_empty 'VAULT_TOKEN env variable' "$VAULT_TOKEN"

certbot-vault-setup.sh

if [ "renew" == "$1" ]; then
  exec certbot renew --dns-route53 --dns-route53-propagation-seconds 30
fi

exec "$@"