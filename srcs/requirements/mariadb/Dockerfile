# TODO (Dia 2)
# - FROM debian:<penultima_stable>-slim  (o alpine:<penultima_stable>) -- NUNCA :latest
# - instalar mariadb-server
# - COPY conf/ y tools/entrypoint.sh
# - el entrypoint debe:
#     * inicializar el datadir si esta vacio
#     * crear la base de datos (MYSQL_DATABASE) y dos usuarios (MYSQL_USER + otro)
#     * leer las contrasenas de /run/secrets/db_password y /run/secrets/db_root_password
#       (NUNCA como valor literal en este Dockerfile)
# - CMD/ENTRYPOINT debe arrancar mariadbd en foreground (proceso PID 1), sin
#   tail -f / sleep infinity / while true / bash a secas
