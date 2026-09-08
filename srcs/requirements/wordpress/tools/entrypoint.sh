#!/bin/bash
set -e

WP_PATH=/var/www/html

DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/credentials)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

# depends_on solo espera a que el contenedor de mariadb arranque, no a que
# mariadbd acepte conexiones. Mientras el bootstrap del Dia 2 esta en marcha,
# el puerto esta cerrado (--skip-networking): en cuanto responde, la base
# "wordpress" y el usuario ya existen, sin condiciones de carrera.
echo "[entrypoint] waiting for mariadb:3306..."
until (exec 3<>/dev/tcp/mariadb/3306) 2>/dev/null; do
	sleep 1
done
exec 3<&- 3>&-
echo "[entrypoint] mariadb is reachable."

if [ ! -f "$WP_PATH/wp-config.php" ]; then
	echo "[entrypoint] no existing wp-config.php, installing WordPress..."

	wp core download --allow-root --path="$WP_PATH"

	wp config create --allow-root --path="$WP_PATH" \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost=mariadb

	wp core install --allow-root --path="$WP_PATH" \
		--url="https://${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email

	wp user create --allow-root --path="$WP_PATH" \
		"${WP_USER}" "${WP_USER_EMAIL}" \
		--role=editor \
		--user_pass="${WP_USER_PASSWORD}"

	chown -R www-data:www-data "$WP_PATH"

	echo "[entrypoint] WordPress installed."
else
	echo "[entrypoint] existing wp-config.php found, skipping install."
fi

exec php-fpm8.2 -F
