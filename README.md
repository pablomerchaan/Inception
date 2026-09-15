*This project has been created as part of the 42 curriculum by paperez-.*

## Description

Inception is a system administration project: a small, self-hosted infrastructure built entirely with Docker, from scratch, without relying on any pre-built service images. It sets up a WordPress website backed by MariaDB, served exclusively through NGINX over TLS, with each service running in its own container, built from its own `Dockerfile`, connected through a dedicated Docker network, and persisting its data in named volumes on the host.

The goal isn't just "make WordPress run in Docker" — it's to understand and implement, by hand, the sysadmin concerns that a ready-made image would normally hide: how a container's first-boot initialization differs from a later restart, how secrets should (and shouldn't) reach a running process, why the main process of a container has to be PID 1, and how to reason about persistence, networking and TLS between isolated containers.

## Instructions

Requirements: a machine (in this project's case, a Debian virtual machine) with Docker and Docker Compose (the `docker compose` plugin, not the old standalone `docker-compose`) installed, and `make`.

```
git clone https://github.com/pablomerchaan/Inception.git
cd Inception
```

Before the first run, two things need to exist locally (both are git-ignored on purpose, see the Secrets vs Environment Variables comparison below):

- `secrets/*.txt` — one password per file (`credentials.txt`, `db_password.txt`, `db_root_password.txt`, `wp_user_password.txt`). Each `secrets/*.txt.example` shows the expected format; copy it and put a real random password in it, e.g. `openssl rand -base64 24 | tr -d '=+/\n' | cut -c1-24 > secrets/db_password.txt`.
- `srcs/.env` — non-sensitive configuration (domain name, database/user names, WordPress titles and emails). See `DEV_DOC.md` for the exact variables expected.

Then, from the repository root:

```
make        # builds the three images and starts the stack (detached)
make down   # stops and removes the containers (keeps volumes/data)
make clean  # down + removes this project's images (keeps volumes/data)
make fclean # clean + removes the named volumes AND the data on disk
make re     # fclean + make
```

Once it's up, the site is reachable at `https://<login>.42.fr/` (self-signed certificate — the browser will warn about it, that's expected). See `USER_DOC.md` for day-to-day usage and `DEV_DOC.md` for how the environment is put together.

## Resources

- [Docker documentation](https://docs.docker.com/) — images, Dockerfiles, Compose file reference, volumes, networking.
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/) — `secrets:`, `depends_on` conditions, `healthcheck`.
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/) — `mariadb-install-db`, user/privilege management.
- [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/) — non-interactive WordPress installation (`wp core install`, `wp user create`).
- [NGINX documentation](https://nginx.org/en/docs/) — `ssl_protocols`, FastCGI configuration.
- [`pid_namespaces(7)` man page](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html) — why PID 1 of a container has special signal-handling semantics (relevant to why `docker exec <container> kill -9 1` doesn't work, but a real crash does).

**How AI was used:** Claude (Claude Code) was used throughout as a pair-programming and sysadmin-tutoring tool, not as a black box that wrote the project unsupervised:
- Turning the subject PDF into a day-by-day study/implementation plan, and explaining the *why* behind each Docker/Linux mechanism (PID 1, named volumes vs bind mounts, Docker secrets, entrypoint bootstrap patterns) before writing any file.
- Pair-writing the three `Dockerfile`s and entrypoint scripts, including diagnosing real bugs hit along the way (a missing `/run/mysqld` directory crashing MariaDB, Docker's volume "copy-up" behaviour silently defeating the first-boot check, an anonymous-MySQL-user login collision, a missing `ca-certificates` package breaking `wp-cli`'s HTTPS download).
- Reviewing the `Makefile` and `docker-compose.yml` for correctness and safety (catching that `docker system prune` is a system-wide, not project-scoped, operation, and that `docker kill`/`docker stop` do **not** trigger `restart: unless-stopped` by Docker's own design — see the Q&A-style notes in this repository's development history).
- Guiding the VirtualBox + Debian VM setup and the migration of the project into it, step by step, run interactively by the author to build hands-on familiarity with the tools for the defense.

Every command and every line of configuration was reviewed, tested, and re-run by the author before being kept — see the four comparisons below for the kind of reasoning that shaped the final design.

## Project description

### Virtual Machine vs Docker

A virtual machine virtualizes an entire computer: it runs its own full kernel, boots independently, and is managed by a hypervisor that emulates (or paravirtualizes) hardware — CPU, memory, disks, NICs. Starting a VM takes tens of seconds and its disk image is typically gigabytes in size, because it carries a whole operating system.

A Docker container does not virtualize hardware at all: it's a set of host OS processes isolated from the rest of the system using kernel features (namespaces for isolation, cgroups for resource limits). All containers on a machine share the *same* running kernel — there is no second kernel to boot. That's why a container starts in milliseconds and an image can be a few tens of megabytes.

This project uses both, for different reasons: **one** VM (mandated by the subject) provides the isolated, disposable "computer" the whole exercise runs on, while **three** containers *inside* that VM provide the actual service isolation (NGINX must not share a filesystem or process tree with MariaDB, for instance) — without paying the cost of three separate kernels for what is fundamentally three cooperating processes.

### Docker Secrets vs Environment Variables

Both are ways of getting a value into a running container, but they have very different exposure. A value baked into an image via `ENV`, or passed as a build `ARG`, becomes part of the image's layers: it is visible forever with `docker history`, `docker inspect`, or by exporting the image, even if the file that "used" it was later deleted in a subsequent layer. `.env` files passed via `env_file:` behave similarly in effect — the values land inside the running container's environment, readable by any process in it (and by anyone who can `docker inspect` or `docker exec` it).

Docker secrets are mounted, at *runtime only*, as files under `/run/secrets/<name>` inside the container — `/run` is `tmpfs`, so the value never touches disk, is never part of any image layer, and disappears the moment the container stops. Nothing about a secret is visible via `docker history`.

This project follows that split deliberately: `srcs/.env` holds configuration that isn't sensitive by itself (a database *name*, a WordPress *title*, the domain) — `MYSQL_DATABASE`, `MYSQL_USER`, `WP_TITLE`, `WP_ADMIN_USER`, etc. Anything that actually grants access — the four passwords (`db_password`, `db_root_password`, `credentials` for the WordPress admin, `wp_user_password`) — is declared as a Docker secret in `docker-compose.yml`, backed by a git-ignored file under `secrets/`, and read by each entrypoint script from `/run/secrets/...` at container start.

### Docker Network vs Host Network

With `network: host`, a container shares the host's network namespace outright: no isolation, the container sees (and can bind) the host's real interfaces and ports directly, and it can reach — and be reached by — anything the host itself can. It also means two containers can silently collide on the same port, and a compromised container has direct access to the host's network stack. The subject explicitly forbids this (and `--link`, its older, similarly loose cousin).

A user-defined Docker network (a bridge, in this project: `inception`) instead gives every container its *own* isolated network namespace, connected to the others only through a virtual bridge. Containers reach each other by **service name** (Docker's embedded DNS resolves `mariadb`, `wordpress`, `nginx` to the right internal IP) over exactly the ports they expose to that network — nothing more. Only NGINX's port 443 is published to the host at all (`ports: "443:443"`); MariaDB's 3306 and php-fpm's 9000 are reachable *only* from other containers already on the `inception` network, never from the host or the outside world. This is what makes "NGINX is the only entrypoint" an enforced property of the setup, not just a convention.

### Docker Volumes vs Bind Mounts

A bind mount ties a container path directly to an arbitrary path on the host filesystem, specified inline wherever it's used (`- /some/host/path:/container/path`). Docker itself doesn't track it as a first-class object — there's no `docker volume` entry, no lifecycle, no driver; it's whatever happens to be at that host path, sharing the host's exact permissions and quirks (which is precisely why the two persistent stores this project produces — MariaDB's and WordPress's — chose the other option).

A named volume is a Docker-managed entity: created and referenced by name (`db_data`, `wp_data`), listed with `docker volume ls`, inspectable with `docker volume inspect`, and normally stored under Docker's own directory (`/var/lib/docker/volumes/<name>/_data`) rather than an arbitrary host path — which would put it *outside* `/home/<login>/data` unless something is configured otherwise. The subject requires both: a genuine named volume, **and** for its data to live at that specific host path. This project reconciles the two with the `local` driver's `driver_opts` (`type: none`, `o: bind`, `device: /home/<login>/data/...`): the volume is still a real, Docker-managed named volume — created, torn down, and inspected exactly like any other — its *storage backend* just happens to be a specific host directory instead of Docker's own default one. `docker volume inspect` on either volume confirms this: it reports as an ordinary `local` volume, whose `Mountpoint` and `Options.device` both resolve under `/home/<login>/data`.
