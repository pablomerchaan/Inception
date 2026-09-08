FROM debian:bookworm-slim

# El postinst de mariadb-server ya deja un datadir inicializado en /var/lib/mysql
# durante el build; hay que vaciarlo para que el volumen empiece realmente vacio
# y sea el entrypoint quien decida cuando inicializar (si no, el "copy-up" de
# Docker copia ese contenido horneado al volumen y el entrypoint nunca hace bootstrap).
RUN apt-get update && \
    apt-get install -y --no-install-recommends mariadb-server && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/lib/mysql/*

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["entrypoint.sh"]
