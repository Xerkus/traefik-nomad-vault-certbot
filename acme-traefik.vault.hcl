path "secrets/metadata/acme/certs/+" {
  capabilities = ["list", "read"]
}

path "secrets/data/acme/certs/+" {
  capabilities = ["read"]
}