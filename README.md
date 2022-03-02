# traefik-nomad-vault-certbot
Sample setup for running Traefik in Nomad with static certs from HashiCorp Vault with certs managed by certbot

This setup was not run once, expect errors on typos and other stupid mistakes.

Assumptions:

- Certbot is setup to use AWS Route 53 dns challenge. Vault is expected to provide
  [AWS STS AssumeRole](https://www.vaultproject.io/docs/secrets/aws#sts-assumerole) token at `aws/sts/certbot-iam` with
  IAM policy giving access to Route53 Zone(s) for managed certs
- kv2 secrets engine mounted as `secrets`
- `secrets/acme/account` imported manually from certbot after LE account registration:
  - `account_id`: LE account in the format `https://acme-v02.api.letsencrypt.org/acme/acct/1234567`
  - `id`: certbot account id that could be found in `/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory`
  - `meta`: meta.json from certbot account folder
  - `private_key`: private_key.json from certbot account folder
  - `regr`: regr.json from certbot account folder
- `secrets/acme/certs/{cert_name}` Could be created by certbot hook using oneshot job to issue cert. `cert_name` is the
  value that is used in traefik job template 
  - `cert`: content of `cert.pem`
  - `chain`: content of `chain.pem`
  - `fullchain`: content of `fullchain.pem`
  - `privkey`: content of `privkey.pem`
  - `renewal`: certbot renewal config, it is not actually used and new one is generated in certbot-vault-setup.sh script
  - `domains`: list of domains that was used to issue or renew cert. Informational
