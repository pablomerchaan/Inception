# Developer documentation

This document explains how to set the project up from scratch, how the build/launch pipeline works, the commands used to manage it day-to-day, and where its data actually lives.

## Setting up the environment from scratch

### Prerequisites

- A machine running Docker + the `docker compose` plugin (v2, invoked with a space — not the legacy `docker-compose` standalone script) and `make`. This project targets Debian (`debian:bookworm-slim` as the base image for all three services — the penultimate Debian stable release at the time of writing, since the latest stable is not allowed).
- On the machine that will run the containers, a real login-named user must exist (e.g. `paperez-`), because `/home/<login>/data` is where the persistent volumes live, and this repo's defaults assume that login.

### Configuration files (not tracked by git)

Two things must be created manually before the first `make` — both are intentionally excluded from version control (see `.gitignore`) because they hold real, environment-specific values.

**`srcs/.env`** (non-sensitive configuration):

```
DOMAIN_NAME=<login>.42.fr
DATA_DIR=/home/<login>/data
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
WP_TITLE=Inception
WP_ADMIN_USER=owner42
WP_ADMIN_EMAIL=<login>@student.42madrid.com
WP_USER=editor42
WP_USER_EMAIL=editor.<login>@student.42madrid.com
```

`WP_ADMIN_USER` must not contain `admin`/`administrator` (in any case) — the subject forbids it.
`DATA_DIR` defaults (via `${DATA_DIR:-/home/<login>/data}` in `docker-compose.yml`) to the real delivery path; it exists as a variable specifically so local development on a machine where that path isn't writable can override it (`DATA_DIR=/home/otheruser/data make up`) without touching any tracked file.

**`secrets/*.txt`** (one real password per file, plain text, one line):

```
secrets/db_root_password.txt
secrets/db_password.txt
secrets/credentials.txt
secrets/wp_user_password.txt
```

Each has a `secrets/*.txt.example` counterpart committed to git showing the expected shape. Generate real ones with, e.g.:

```
openssl rand -base64 24 | tr -d '=+/\n' | cut -c1-24 > secrets/db_password.txt
```

### Domain resolution

`DOMAIN_NAME` must resolve, on whatever machine will *browse* to the site, to the IP of the machine running Docker — add a line to `/etc/hosts` there:

```
<vm-ip>  <login>.42.fr
```

## Building and launching (Makefile + Docker Compose)

```
make            # = make up: prepares $(DATA_DIR), builds the 3 images, starts detached
make build      # only builds the images
make up         # prepares dirs, builds, starts (same as `make`/`make all`)
make down       # stops and removes containers (network too); volumes/data untouched
make stop       # stops containers without removing them
make clean      # down + removes this project's built images only (volumes/data kept)
make fclean     # clean + removes the named volumes AND the data under $(DATA_DIR)
make re         # fclean + up — full clean rebuild
```

The `Makefile` invokes `docker compose -f srcs/docker-compose.yml -p inception`, passing its own `DATA_DIR` value as an environment variable to every invocation — this is what keeps the directory `prepare` creates and the directory the volumes actually mount in sync, even if `srcs/.env`'s own `DATA_DIR` is stale.

`fclean` avoids two things on purpose: `sudo rm -rf` (the data directory's files are owned by the in-container `mysql`/`www-data` UIDs, not the host user, so a plain `rm` would fail without it — but `sudo rm -rf` on a whole directory tree is more destructive than necessary and requires an interactive password) and `docker system prune` (which operates on *all* Docker state on the machine, not just this project's — it would happily remove unrelated images/containers belonging to something else entirely). Instead, `fclean` uses `docker compose down -v --rmi all` (scoped to this project only) plus a disposable container that only deletes the two known data subdirectories.

### Build order and startup sequencing

Compose builds `mariadb`, `wordpress`, `nginx` (context = `srcs/requirements/<service>`, one Dockerfile each, no `:latest` tag anywhere). At startup, `depends_on: condition: service_healthy` chains them: WordPress won't start until MariaDB's `healthcheck` (`mysqladmin ping`) succeeds, and NGINX won't start until WordPress's `healthcheck` (`wp-config.php` exists **and** php-fpm answers on port 9000) succeeds. Without this, `docker compose up` only waits for a container to *start*, not for the service inside it to actually be ready — which showed up in practice as an occasional transient `403` from NGINX on a cold `make up`, before WordPress had finished its one-time install.

Each entrypoint script follows the same shape: check whether this is a genuine first boot (an empty datadir for MariaDB, no `wp-config.php` for WordPress), do one-time setup only if so, then `exec` the real foreground daemon (`mariadbd`, `php-fpm8.2 -F`, `nginx -g "daemon off;"`) so it becomes PID 1 and receives signals directly — no wrapper shell, no `tail -f`/`sleep infinity`-style keep-alive hacks.

## Managing containers and volumes

```
docker compose -f srcs/docker-compose.yml ps                 # status + health
docker logs <mariadb|wordpress|nginx>                         # a container's logs
docker compose -f srcs/docker-compose.yml exec <service> sh   # shell inside a running container
docker volume ls                                               # inception_db_data, inception_wp_data
docker volume inspect inception_db_data                        # shows Mountpoint/Options.device
```

To simulate a real crash and confirm the automatic-restart requirement (`restart: unless-stopped`) — note that `docker kill`/`docker stop` are treated by Docker as *intentional* actions and will **not** trigger a restart, by design:

```
sudo kill -9 $(docker inspect <service> --format '{{.State.Pid}}')
```

## Where the data lives and how it persists

Two named volumes, backed by specific host paths via the `local` driver's `driver_opts` (`type: none`, `o: bind`, `device: ...`) rather than Docker's default internal storage:

- `db_data` → `/var/lib/mysql` inside `mariadb`, backed by `$(DATA_DIR)/mariadb` on the host.
- `wp_data` → `/var/www/html` inside both `wordpress` and `nginx`, backed by `$(DATA_DIR)/wordpress` on the host.

`$(DATA_DIR)` resolves to `/home/<login>/data` by default (the subject's required location). Because the data lives on the host, not inside the container's writable layer, it survives `make down`/`make down && make up`, container crashes and restarts, and even removing the containers and images outright (`make clean`) — only `make fclean` (or manually deleting the host directories) actually removes it.
