locals {
  certbot_image = "localhost/certbot/certbot:latest"
  vault_addr    = "http://localhost:8200"
}

job "certbot-vault-oneshot" {
  type = "batch"

  group "certbot" {
    vault {
      policies    = ["certbot-vault", "certbot-vault-iam"]
      env         = true
      change_mode = "restart"
    }

    task "certbot" {
      driver = "docker"
      config {
        image = local.certbot_image
        # issue new certificate
        args = [
          "certbot",
          "certonly",
          "--cert-name=example.com", # also vault cert key name
          "-d=example.com,www.example.com",
          "--non-interactive"
        ]
      }

      # See https://github.com/hashicorp/nomad/issues/2393 for VAULT_ADDR
      env {
        VAULT_ADDR = local.vault_addr
      }

      resources {
        memory = 128
      }

      restart {
        attempts = 3
        delay    = "25s"
        interval = "5m"
        mode     = "delay"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/file.env"
        env         = true
        change_mode = "restart"

        data = <<-EOH
        {{ with secret "aws/sts/certbot-vault-iam" "ttl=30m" }}
        AWS_ACCESS_KEY_ID="{{ .Data.access_key }}"
        AWS_SECRET_ACCESS_KEY="{{ .Data.secret_key }}"
        AWS_SESSION_TOKEN="{{ .Data.security_token }}"
        {{ end }}
        EOH
      }
    }
  }
}
