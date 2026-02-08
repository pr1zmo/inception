# **************************************************************************** #
#                                  CONFIG                                      #
# **************************************************************************** #

include .env

ENV_FILE		:= .env
COMPOSE_FILE    := srcs/docker-compose.yaml
DC              := docker compose --env-file ./$(ENV_FILE) -f $(COMPOSE_FILE)
DATA_DIR        := /home/$(USER)/data
VOLUME_SERVICES := wordpress mariadb cuma

# **************************************************************************** #
#                                   RULES                                      #
# **************************************************************************** #

.PHONY: all bonus dirs clean fclean re logs

all: dirs
	@echo "Building and starting containers..."
	$(DC) up -d --build

bonus: dirs
	@echo "Building and starting bonus containers..."
	$(DC) up -d --build --profile bonus

dirs:
	@echo "Creating data directories in $(DATA_DIR)"
	@mkdir -p $(DATA_DIR)
	@for service in $(VOLUME_SERVICES); do \
		mkdir -p $(DATA_DIR)/$$service; \
		echo "  - Created $(DATA_DIR)/$$service"; \
	done

clean:
	@echo "Removing unused images and volumes..."
	@docker system prune -f --volumes

fclean:
	@echo "Stopping all containers for this project..."
	-$(DC) down -v --rmi all --remove-orphans
	@echo "Removing all images and volumes..."
	@docker system prune -a -f --volumes

re: fclean all

logs:
	$(DC) logs -f