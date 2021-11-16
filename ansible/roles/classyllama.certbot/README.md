# Ansible Role: Certbot / Let's Encrypt

Installs Certbot (Let's Encrypt) for RHEL/CentOS with Nginx.

Auto-renew is handled by a snap timer. View with `systemctl list-timers` and test with `certbot renew --dry-run`.

## Requirements

* Certbot requires Git be installed

## Role Configuration

* Set `certbot_generate` to true and certbot will attempt to generate defined SSL certificates (requires public DNS)

* Email address to register domains with:

        certbot_email: admin@example.com

* List of domains to create individual certificates for:

        certbot_domains: 
          - stage.example.com
          - stage.awesome.com

## Dependencies

* In order for certbot to verify domain control, public DNS for each domain must be setup prior to running and an nginx server must exist for each domain

## Example Usage

    vars:
        certbot_generate: true
        certbot_email: admin@example.com
        certbot_domains: [ stage.example.com ]
    roles:
        - certbot
