locals {
  # key names for certs in vault. Certs must exist or job will fail
  vault_certs = [
    "example.com",
    "example.org",
  ]
}

job "traefik" {
  type = "system"

  group "edge" {

    network {
      mode = "bridge"

      port "http" {
        static = 80
        to     = 80
      }

      port "https" {
        static = 443
        to = 443
      }

      port "health" {
        to = 8082
      }
    }

    service {
      name = "traefik-ingress"
      port = "http"
      task = "traefik"

      check {
        type = "http"
        path = "/ping"
        port = "health"
        interval = "10s"
        timeout = "2s"
      }

      connect {
        native = true
      }
    }

    task "traefik" {
      driver = "docker"
      config {
        image = "traefik:v2.6.0"
        args = [
          "--configFile=/local/conf/traefik.toml",
        ]
      }

      vault {
        policies = ["acme-traefik"]
        env = false
        change_mode = "noop"
      }

      template {
        destination = "${NOMAD_TASK_DIR}/conf/traefik.toml"
        env = false
        change_mode = "restart"
        splay = "1m"
        data = <<-EOH
        [entryPoints.http]
          address = ":80"
          [entryPoints.http.http]
            [entryPoints.http.http.redirections]
              [entryPoints.http.http.redirections.entryPoint]
                to = "https"
                scheme = "https"
                permanent = true
          [entryPoints.https]
            address = ":443"
            [entryPoints.https.http]
              middlewares = ["hsts@file"]
              [entryPoints.https.http.tls]
          [entryPoints.ping]
            address = ":8082"
        [tls.options]
          [tls.options.default]
            sniStrict = true
            minVersion = "VersionTLS12"
        [providers]
          [providers.file]
            directory = "/local/conf/dynamic"
          [providers.consulCatalog]
            connectAware = true
            exposedByDefault = false
            connectByDefault = false
            serviceName = "traefik-ingress"
            cache = true
        # /ping endpoint
        [ping]
          entryPoint = "ping"
        [log]
          format = "json"
        [accessLog]
          format = "json"
        EOH
      }

      template {
        destination = "${NOMAD_TASK_DIR}/conf/dynamic/traefik.toml"
        env = false
        change_mode = "noop"
        splay = "1m"
        data = <<-EOH
        [http]
          [http.middlewares]
            [http.middlewares.hsts.headers]
              stsSeconds=63072000
              stsIncludeSubdomains=true
              stsPreload=true
        EOH
      }

      dynamic "template" {
        for_each = local.vault_certs
        content {
          destination = "${NOMAD_TASK_DIR}/conf/dynamic/cert-${template.value}.toml"
          env = false
          change_mode = "restart"
          splay = "1m"
          data = <<-EOH
          [[tls.certificates]]
            certFile = "/secrets/certs/${template.value}.crt"
            keyFile =  "/secrets/certs/${template.value}.key"
          EOH
        }
      }

      dynamic "template" {
        for_each = local.vault_certs
        content {
          destination = "${NOMAD_SECRETS_DIR}/certs/${template.value}.crt"
          env = false
          change_mode = "restart"
          splay = "1m"
          data = <<-EOH
          {{- with secret "secrets/acme/certs/${template.value}" -}}
          {{.Data.data.fullchain}}
          {{- end -}}
          EOH
        }
      }

      dynamic "template" {
        for_each = local.vault_certs
        content {
          destination = "${NOMAD_SECRETS_DIR}/certs/${template.value}.key"
          env = false
          change_mode = "restart"
          splay = "1m"
          data = <<-EOH
          {{- with secret "secrets/acme/certs/${template.value}" -}}
          {{.Data.data.privkey}}
          {{- end -}}
          EOH
        }
      }
    }
  }
}
