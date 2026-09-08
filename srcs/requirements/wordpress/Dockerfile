FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        php-fpm php-cli php-mysql php-curl php-gd php-xml php-mbstring php-zip php-intl \
        curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# wp-cli es una herramienta de sistema (no datos de usuario), por eso vive
# horneada en la imagen; WordPress en si se descarga en el entrypoint, en
# tiempo de ejecucion, porque esos ficheros son datos que viven en el volumen.
RUN curl -o /usr/local/bin/wp -fSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["entrypoint.sh"]
