FROM certbot/dns-route53:v1.23.0

RUN apk add --no-cache \
      bash \
      jq \
      && rm -rf /var/cache/apk/*
COPY --from=vault:1.9.3 /bin/vault /usr/local/bin/vault
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/
COPY --chmod=0755 certbot-vault-setup.sh /usr/local/bin/
COPY --chmod=0755 hook-update-vault.sh /etc/letsencrypt/renewal-hooks/deploy/00-update-vault.sh
COPY cli.ini /etc/letsencrypt/cli.ini
COPY --from=gcr.io/google_containers/pause-amd64:3.1 /pause /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
