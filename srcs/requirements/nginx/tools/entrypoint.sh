#!/bin/bash
set -e

mkdir -p /etc/nginx/ssl

# Autofirmado: nadie lo valida contra una CA, asi que no hace falta persistirlo
# en un volumen. Se regenera en cada arranque, leyendo el dominio real de .env.
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/nginx/ssl/inception.key \
	-out /etc/nginx/ssl/inception.crt \
	-subj "/CN=${DOMAIN_NAME}" \
	-addext "subjectAltName=DNS:${DOMAIN_NAME}" \
	2>/dev/null

exec nginx -g "daemon off;"
