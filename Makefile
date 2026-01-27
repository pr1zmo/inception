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

.PHONY: all down re clean fclean purge dirs logs

all: dirs
	@echo "Building and starting containers..."
	$(DC) up -d --build

dirs:
	@echo "Creating data directories in $(DATA_DIR)"
	@mkdir -p $(DATA_DIR)
	@for service in $(VOLUME_SERVICES); do \
		mkdir -p $(DATA_DIR)/$$service; \
		echo "  - Created $(DATA_DIR)/$$service"; \
	done

setup-hosts:
	@echo "Adding hosts entry (requires sudo)..."
	@grep -q "$(DOMAIN_NAME)" /etc/hosts || echo "127.0.0.1 $(DOMAIN_NAME)" | sudo tee -a /etc/hosts

down:
	@echo "Stopping containers..."
	$(DC) down

clean: down
	@echo "Removing containers..."
	$(DC) down -v

purge: down
	@echo "Purging all project data..."
	-$(DC) down -v --rmi all --remove-orphans
	
	@echo "Removing all project volumes..."
	-docker volume rm $$(docker volume ls -q) 2>/dev/null || true
	
	@echo "Removing all project images..."
	-docker rmi $$(docker images -q) 2>/dev/null || true
	
	@echo "Removing data directory: $(DATA_DIR)"
	-sudo rm -rf $(DATA_DIR)
	
	@echo "Purge complete! All project data has been removed."

re: fclean all

logs:
	$(DC) logs -f

ps:
	$(DC) ps

exec-nginx:
	$(DC) exec nginx sh

exec-wordpress:
	$(DC) exec wordpress sh

exec-mariadb:
	$(DC) exec mariadb sh