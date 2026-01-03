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

            [Service]
            Restart=always
            RestartSec=10
            ExecStart=/usr/bin/docker run --rm --network custom-bridge -p 80:80 -p 443:443 --mount 'type=bind,source=/mnt/disks/data/caddy/Caddyfile,target=/etc/caddy/Caddyfile,readonly' --mount 'type=bind,source=/mnt/disks/data/caddy/data,target=/data' --mount 'type=bind,source=/mnt/disks/data/caddy/config,target=/config' --name=caddy caddy:alpine
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
            ExecStart=/usr/bin/docker run --rm --network custom-bridge --env-file /etc/actual-mcp.env --mount 'type=bind,source=/mnt/disks/data/actual-mcp-data,target=/data' --name=actual_mcp sstefanov/actual-mcp:latest --sse --enable-write --enable-bearer
            ExecStop=-/usr/bin/docker stop actual_mcp
            EOT6
    },
    {
      path        = "/tmp/Caddyfile"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT4
            ${var.actual_fqdn} {
                encode gzip zstd
                reverse_proxy actual_server:5006
            }

            mcp.${var.actual_fqdn} {
                encode gzip zstd
                reverse_proxy actual_mcp:3000
            }
            EOT4
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
            cp /tmp/Caddyfile /mnt/disks/data/caddy/Caddyfile
            EOT5
    }
  ]

  runcmd = [
    "docker network create custom-bridge",
    "systemctl daemon-reload",
    "systemctl start caddy.service",
    "systemctl start actual.service",
    "systemctl start duckdns.service",
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
    "mkdir -p /mnt/disks/data/actual-mcp-data"
  ]
})}
  EOT
}
