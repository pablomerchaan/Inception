NAME		= inception
LOGIN		= paperez-
DATA_DIR	= /home/$(LOGIN)/data
COMPOSE		= DATA_DIR=$(DATA_DIR) docker compose -f srcs/docker-compose.yml -p $(NAME)

.PHONY: all up build down stop clean fclean re prepare

all: up

prepare:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

build: prepare
	$(COMPOSE) build

up: prepare
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

# quita contenedores, red e imagenes de este proyecto; conserva volumenes y datos
clean:
	$(COMPOSE) down --rmi all

# limpieza total: tambien volumenes y los datos reales en $(DATA_DIR).
# Esos ficheros quedan con dueno mysql/www-data (el UID que usa el contenedor),
# por eso se borran desde un contenedor efimero en vez de un "rm -rf" directo,
# que fallaria por permisos sin sudo.
fclean:
	$(COMPOSE) down -v --rmi all
	@if [ -d "$(DATA_DIR)" ]; then \
		docker run --rm -v $(DATA_DIR):/data debian:bookworm-slim \
			bash -c "rm -rf /data/mariadb /data/wordpress"; \
	fi

re: fclean up
