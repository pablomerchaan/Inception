FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx openssl && \
    rm -rf /var/lib/apt/lists/*

# Sobreescribe el site "default" de Debian (ya enlazado en sites-enabled/):
# de ahi cuelga el unico server block, solo en 443, sin puerto 80.
COPY conf/nginx.conf /etc/nginx/sites-available/default
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["entrypoint.sh"]
