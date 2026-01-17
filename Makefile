# **************************************************************************** #
#                                  CONFIG                                      #
# **************************************************************************** #

include .env

COMPOSE_FILE := srcs/docker-compose.yml
DC           := docker-compose --env-file .env -f $(COMPOSE_FILE)

DATA_DIR := /home/$(USER)/data


# **************************************************************************** #
#                                   RULES                                      #
# **************************************************************************** #

.PHONY: all down re purge dirs

all: dirs
	$(DC) up -d --build

dirs:
	@echo "📁 Creating data directories in $(DATA_DIR)"
	@mkdir -p $(DATA_DIR)
	@for service in $(VOLUME_SERVICES); do \
		mkdir -p $(DATA_DIR)/$$service; \
	done

down:
	$(DC) down

re: down all

purge:
	@echo "🔥 Stopping containers and removing everything"
	-$(DC) down -v --rmi all --remove-orphans

	@echo "🧹 Removing dangling images"
	-docker image prune -af

	@echo "🧹 Removing unused volumes"
	-docker volume prune -f

	@echo "🧹 Removing unused networks"
	-docker network prune -f

	@echo "💣 Removing data directory: $(DATA_DIR)"
	-sudo rm -rf $(DATA_DIR)

