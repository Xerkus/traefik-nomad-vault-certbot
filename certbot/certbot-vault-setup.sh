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

function install_cert {
  local readonly account="$1"
  local readonly cert_name="$2"
  local readonly cert_data="$3"

  assert_not_empty "account" "$account"
  assert_not_empty "cert_name" "$cert_name"
  assert_not_empty "cert_data" "$cert_data"


  local readonly archive_dir="/etc/letsencrypt/archive/${cert_name}"
  local readonly live_dir="/etc/letsencrypt/live/${cert_name}"

  mkdir -p "$archive_dir"
  mkdir -p "$live_dir"
  mkdir -p /etc/letsencrypt/renewal

  #create new renewal config. Hook stores config with cert data, so that one could be used instead.
  cat <<EOF > "/etc/letsencrypt/renewal/${cert_name}.conf"
# renew_before_expiry = 30 days
version = 1.23.0
archive_dir = ${archive_dir}
cert = ${live_dir}/cert.pem
privkey = ${live_dir}/privkey.pem
chain = ${live_dir}/chain.pem
fullchain = ${live_dir}/fullchain.pem

# Options used in the renewal process
[renewalparams]
account = ${account}
key_type = ecdsa
server = https://acme-v02.api.letsencrypt.org/directory
authenticator = dns-route53
EOF

  mkdir -p "/etc/letsencrypt/archive/${cert_name}"
  for field in cert chain privkey fullchain; do
    echo "$cert_data" | jq -e -j ".data.data.${field}" > "${archive_dir}/${field}1.pem"
    ln -sf "${archive_dir}/${field}1.pem" "${live_dir}/${field}.pem"
  done
}

function run {
  assert_is_installed "vault"
  assert_is_installed "jq"

  assert_not_empty 'VAULT_ADDR env variable' "$VAULT_ADDR"
  assert_not_empty 'VAULT_TOKEN env variable' "$VAULT_TOKEN"

  local readonly accounts_dir
  accounts_dir=/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory

  local readonly account_data
  account_data=$(vault kv get --format=json secrets/acme/account)
  local readonly account_id
  account_id="$(echo "$account_data" | jq -e -j '.data.data.id' )"

  local readonly account_path
  account_path="${accounts_dir}/${account_id}"
  mkdir -p "$account_path"

  echo "$account_data" | jq -e -j '.data.data.meta' > "$account_path/meta.json"
  echo "$account_data" | jq -e -j '.data.data.private_key' > "$account_path/private_key.json"
  echo "$account_data" | jq -e -j '.data.data.regr' > "$account_path/regr.json"

  local readonly certs
  certs="$(vault kv list --format=json secrets/acme/certs/ | jq -r '.[]')"

  local cert_name
  local cert_data
  for cert_name in $certs; do
    cert_data=$(vault kv get --format=json "secrets/acme/certs/${cert_name}")
    if [[ $(echo "$cert_data" | jq -j '.data.metadata.custom_metadata.enabled') == "false" ]]; then
      # if metadata
      log_info "Skipping disabled cert '${cert_name}'"
      continue
    fi

    log_info "Adding cert '${cert_name}'"
    install_cert "$account_id" "$cert_name" "$cert_data"
  done
}

run "$@"
