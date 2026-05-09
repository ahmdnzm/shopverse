#!/bin/sh
set -eu

# default use k8s service name
: "${API_HOST:=shopverse-backend-svc}"
: "${API_PORT:=8080}"

# Only substitute runtime config vars, leave nginx $host etc intact
envsubst '${API_HOST} ${API_PORT} ${ENVIRONMENT}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
