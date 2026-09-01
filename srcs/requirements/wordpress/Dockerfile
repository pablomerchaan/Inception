# TODO (Dia 3)
# - FROM debian:<penultima_stable>-slim  (o alpine:<penultima_stable>) -- NUNCA :latest
# - instalar php-fpm + extensiones necesarias (php-mysqli, etc.) + wp-cli
# - COPY conf/ y tools/entrypoint.sh
# - el entrypoint debe:
#     * esperar a que mariadb acepte conexiones
#     * descargar wordpress si el volumen esta vacio
#     * generar wp-config.php leyendo credenciales de .env + /run/secrets/*
#     * wp core install no interactivo:
#         - admin: usuario SIN "admin"/"administrator" en el nombre (ver WP_ADMIN_USER)
#         - segundo usuario normal (WP_USER)
# - CMD/ENTRYPOINT debe arrancar php-fpm en foreground (php-fpm -F), sin nginx aqui
