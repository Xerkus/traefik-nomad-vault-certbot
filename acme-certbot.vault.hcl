path "secrets/data/acme/account" {
  capabilities = ["read"]
}

path "secrets/metadata/acme/certs/+" {
  capabilities = ["list", "read"]
}

path "secrets/data/acme/certs/+" {
  capabilities = ["create", "update", "read"]

  # secrets does not support required_parameters. Included for reference
  # required_parameters = ["cert", "chain", "fullchain", "privkey", "renewal"]
}
