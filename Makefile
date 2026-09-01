NAME		= inception
LOGIN		= paperez-
DATA_DIR	= /home/$(LOGIN)/data
COMPOSE		= docker compose -f srcs/docker-compose.yml

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

# removes containers/networks, keeps volumes and data on disk
clean: down
	docker system prune -f

# removes everything, including volumes, images and the data on disk
fclean: down
	$(COMPOSE) down -v --rmi all
	docker system prune -af
	sudo rm -rf $(DATA_DIR)

re: fclean up
