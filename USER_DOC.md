# User documentation

This document explains how to use the Inception stack day-to-day: what it provides, how to start and stop it, how to reach the site and its admin panel, where the credentials live, and how to check that everything is actually working.

## What the stack provides

Three services, each in its own container, working together:

- **NGINX** — the only entrypoint into the whole stack. It serves the site over HTTPS (port 443 only, TLS 1.2/1.3) and forwards PHP requests to WordPress.
- **WordPress (+ php-fpm)** — the actual website: a blog/CMS with an administrator account and a regular editor account.
- **MariaDB** — the database behind WordPress (its posts, users, settings — everything WordPress needs to remember).

You never talk to WordPress or MariaDB directly from outside; NGINX is the single door in.

## Starting and stopping the stack

From the repository root:

```
make        # builds the images (first time / after a change) and starts everything
```

To stop it (containers removed, but your data and images stay):

```
make down
```

To stop and start again without rebuilding:

```
make down && make
```

Check what's currently running:

```
docker compose -f srcs/docker-compose.yml ps
```

All three should show `Up (healthy)`. If one is still `starting`, give it a few seconds — MariaDB and WordPress both do a one-time setup on their very first boot (creating the database, downloading and installing WordPress), and the other services wait for that to finish before starting.

## Accessing the website and the admin panel

Point your browser at:

```
https://<login>.42.fr/
```

(replace `<login>` with the actual login this was set up for — it must also be present in your `/etc/hosts`, pointing at the machine's IP, and matches `DOMAIN_NAME` in `srcs/.env`).

The certificate is self-signed (this project doesn't have a real, publicly-trusted certificate authority behind it), so the browser will show a warning the first time — that's expected; accept it to continue.

To reach the WordPress admin dashboard, go to:

```
https://<login>.42.fr/wp-admin
```

and log in with the administrator account (see below for where to find its password). There are two WordPress user accounts by design:

- An **administrator** (username configured as `WP_ADMIN_USER` in `srcs/.env`) — full control over the site.
- A regular **editor** (username configured as `WP_USER` in `srcs/.env`) — can write and manage content, not administer the site.

## Locating and managing credentials

Nothing sensitive lives in `srcs/.env` — only names (database name, usernames, the site title). The actual passwords live in individual files under `secrets/`, one password per file, and are never committed to git:

| File | What it's for |
|---|---|
| `secrets/db_root_password.txt` | MariaDB `root` (database administrator) password |
| `secrets/db_password.txt` | MariaDB application user (`wp_user`, set via `MYSQL_USER`) password |
| `secrets/credentials.txt` | WordPress administrator account password |
| `secrets/wp_user_password.txt` | WordPress editor account password |

To read one:

```
cat secrets/credentials.txt
```

These files must exist and contain a real value **before** the very first `make up` — that's when each service reads them and sets its passwords accordingly. Changing a password file afterwards does **not** change anything already configured (the containers only read secrets during their one-time setup); to rotate a password for real, you'd need to change both the secret file and the corresponding account (e.g. via `wp user update` or SQL), which is outside the scope of normal day-to-day use.

## Checking that everything works

A quick health check, from the repository root:

```
docker compose -f srcs/docker-compose.yml ps
```

All three services should read `healthy`. Beyond that:

- The site loads at `https://<login>.42.fr/` and shows the WordPress homepage.
- `/wp-admin` accepts the administrator credentials and shows the dashboard.
- If a container is ever killed by something unexpected (a crash, the process dying), it restarts on its own within a few seconds — you don't need to do anything. (Note: manually running `docker stop`/`docker kill` on a container is treated by Docker as an intentional action and will **not** auto-restart it — that's expected behavior, not a malfunction.)
