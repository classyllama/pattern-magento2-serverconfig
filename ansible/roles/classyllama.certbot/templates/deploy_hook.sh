#!/usr/bin/env bash
# {{ ansible_managed }}

# On successful deploy, reload nginx to serve new certs
nginx -t && service nginx reload
