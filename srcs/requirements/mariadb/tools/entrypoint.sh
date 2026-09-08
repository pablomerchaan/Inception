#!/bin/bash
set -e

DATADIR=/var/lib/mysql

# /run es tmpfs y se recrea vacio en cada arranque del contenedor: el paquete
# Debian normalmente crea /run/mysqld via systemd-tmpfiles, que aqui no corre.
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

if [ ! -d "$DATADIR/mysql" ]; then
	echo "[entrypoint] no existing datadir, bootstrapping MariaDB..."

	mariadb-install-db --user=mysql --datadir="$DATADIR" > /dev/null

	# arranque temporal solo por socket unix, sin exponer la red todavia,
	# para poder ejecutar el SQL de configuracion inicial
	mariadbd --user=mysql --datadir="$DATADIR" --skip-networking &
	TMP_PID=$!

	# esperar a que el socket este listo para aceptar conexiones
	until mysqladmin ping --silent 2>/dev/null; do
		sleep 1
	done

	mysql -u root <<-SQL
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
		CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
		DELETE FROM mysql.user WHERE User='';
		DROP DATABASE IF EXISTS test;
		FLUSH PRIVILEGES;
	SQL

	mysqladmin -u root -p"${DB_ROOT_PASSWORD}" shutdown
	wait "$TMP_PID" 2>/dev/null || true

	echo "[entrypoint] bootstrap done."
else
	echo "[entrypoint] existing datadir found, skipping bootstrap."
fi

exec mariadbd --user=mysql --datadir="$DATADIR"
