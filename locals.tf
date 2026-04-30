locals {
  cloud_config = <<-EOT
    #cloud-config
    ${yamlencode({
  write_files = [
    {
      path        = "/etc/systemd/system/duckdns.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT1
            [Unit]
            Description=Start DuckDNS

            [Service]
            Restart=always
            RestartSec=30
            ExecStart=/usr/bin/docker run --rm -e SUBDOMAINS=${var.duckdns_subdomains} -e TOKEN=${var.duckdns_token} --name=duckdns lscr.io/linuxserver/duckdns:latest
            ExecStop=-/usr/bin/docker stop duckdns
            EOT1
    },
    {
      path        = "/etc/systemd/system/caddy.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT2
            [Unit]
            Description=Start Caddy
            After=network-online.target docker.service tailscale.service
            Requires=docker.service tailscale.service

            [Service]
            Restart=always
            RestartSec=10
            ExecStartPre=-/usr/bin/docker stop caddy
            ExecStartPre=-/usr/bin/docker rm caddy
            ExecStart=/usr/bin/docker run --rm --network custom-bridge -p 80:80 -p 443:443 --mount 'type=bind,source=/mnt/disks/data/caddy/Caddyfile,target=/etc/caddy/Caddyfile,readonly' --mount 'type=bind,source=/mnt/disks/data/caddy/data,target=/data' --mount 'type=bind,source=/mnt/disks/data/caddy/config,target=/config' -v /var/run/tailscale:/var/run/tailscale --name=caddy caddy:alpine
            ExecStop=-/usr/bin/docker stop caddy
            EOT2
    },
    {
      path        = "/etc/systemd/system/actual.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT3
            [Unit]
            Description=Start Actual

            [Service]
            ExecStartPre=-/usr/bin/docker stop actual_server
            ExecStartPre=-/usr/bin/docker rm actual_server
            ExecStart=/usr/bin/docker run --rm --network custom-bridge --mount 'type=bind,source=/mnt/disks/data/actual-data,target=/data' --name=actual_server actualbudget/actual-server:latest
            ExecStop=/usr/bin/docker stop actual_server
            ExecStopPost=/usr/bin/docker rm actual_server
            EOT3
    },
    {
      path        = "/etc/actual-mcp.env"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOTENV
            ACTUAL_SERVER_URL=http://actual_server:5006
            ACTUAL_PASSWORD=${var.actual_password}
            ACTUAL_BUDGET_SYNC_ID=${var.actual_budget_sync_id}
            BEARER_TOKEN=${var.mcp_bearer_token}
            EOTENV
    },
    {
      path        = "/etc/systemd/system/actual-mcp.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT6
            [Unit]
            Description=Start Actual Budget MCP Server
            After=actual.service
            Requires=actual.service

            [Service]
            Restart=always
            RestartSec=10
            ExecStartPre=-/usr/bin/docker stop actual_mcp
            ExecStartPre=-/usr/bin/docker rm actual_mcp
            ExecStart=/usr/bin/docker run --name actual_mcp --network custom-bridge --env-file /etc/actual-mcp.env --mount 'type=bind,source=/mnt/disks/data/actual-mcp-data,target=/data' sstefanov/actual-mcp:latest --sse --enable-write --enable-bearer
            ExecStop=-/usr/bin/docker stop actual_mcp
            EOT6
    },
    {
      path        = "/tmp/Caddyfile"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT4
            ${var.actual_fqdn}, actual.tailfd243b.ts.net {
              encode gzip zstd

              # Actual MCP Server (Specific paths first)
              handle /mcp* {
                uri strip_prefix /mcp
                reverse_proxy actual_mcp:3000
              }

              # Main Actual Budget (Catch-all last)
              handle /* {
                reverse_proxy actual_server:5006
              }
            }

            mcp.${var.actual_fqdn} {
              encode gzip zstd
              reverse_proxy actual_mcp:3000
            }

            http://actual {
              redir https://actual.tailfd243b.ts.net{uri}
            }
            EOT4
    },
    {
      path        = "/etc/systemd/system/tailscale.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOTTS
            [Unit]
            Description=Tailscale
            After=docker.service
            Requires=docker.service

            [Service]
            Restart=always
            ExecStartPre=-/usr/bin/docker stop tailscale
            ExecStartPre=-/usr/bin/docker rm tailscale
            ExecStart=/usr/bin/docker run --name tailscale --network host --cap-add=NET_ADMIN --cap-add=SYS_MODULE -v /dev/net/tun:/dev/net/tun -v /mnt/disks/data/tailscale:/var/lib/tailscale -v /var/run/tailscale:/var/run/tailscale -e TS_AUTHKEY="${var.ts_authkey}" -e TS_STATE_DIR=/var/lib/tailscale -e TS_SSH=true -e TS_EXTRA_ARGS="--reset" -e TS_SOCKET=/var/run/tailscale/tailscaled.sock tailscale/tailscale:latest
            ExecStop=/usr/bin/docker stop tailscale
            EOTTS
    },
    {
      path        = "/var/lib/cloud/scripts/per-instance/fs-prepare.sh"
      permissions = "0544"
      owner       = "root"
      content     = <<-EOT5
            #!/bin/bash

            mkfs.ext4 -L data -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/google-persistent-disk-1
            mkdir -p /mnt/disks/data
            mount -t ext4 -o nodev,nosuid /dev/disk/by-id/google-persistent-disk-1 /mnt/disks/data
            mkdir -p /mnt/disks/data/caddy
            mkdir -p /mnt/disks/data/caddy/data
            mkdir -p /mnt/disks/data/caddy/config
            mkdir -p /mnt/disks/data/actual-data
            mkdir -p /mnt/disks/data/actual-mcp-data
            mkdir -p /mnt/disks/data/tailscale
            cp /tmp/Caddyfile /mnt/disks/data/caddy/Caddyfile
            EOT5
    }
  ]

  runcmd = [
    "docker network create custom-bridge || true",
    "systemctl daemon-reload",
    "mkdir -p /var/run/tailscale",
    "systemctl enable tailscale.service",
    "systemctl start tailscale.service",
    "systemctl enable caddy.service",
    "systemctl start caddy.service",
    "systemctl enable actual.service",
    "systemctl start actual.service",
    "systemctl enable duckdns.service",
    "systemctl start duckdns.service",
    "systemctl enable actual-mcp.service",
    "systemctl start actual-mcp.service"
  ]

  bootcmd = [
    "fsck.ext4 -tvy /dev/disk/by-id/google-persistent-disk-1",
    "mkdir -p /mnt/disks/data",
    "mount -t ext4 -o nodev,nosuid /dev/disk/by-id/google-persistent-disk-1 /mnt/disks/data",
    "mkdir -p /mnt/disks/data/caddy",
    "mkdir -p /mnt/disks/data/caddy/data",
    "mkdir -p /mnt/disks/data/caddy/config",
    "mkdir -p /mnt/disks/data/actual-data",
    "mkdir -p /mnt/disks/data/actual-mcp-data",
    "mkdir -p /mnt/disks/data/tailscale"
  ]
})}
  EOT
}
