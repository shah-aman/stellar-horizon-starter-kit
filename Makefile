.PHONY: help init up down restart logs health clean update

# Default network is pubnet
NETWORK ?= pubnet

help: ## Show this help message
	@echo 'Usage: make [target] [NETWORK=pubnet|testnet|futurenet]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize the database
	@echo "Initializing Horizon database..."
	docker compose run --rm --entrypoint="" horizon horizon db init

up: ## Start the stack
	@echo "Starting Stellar Horizon (network: $(NETWORK))..."
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Copy .env.example to .env and configure it."; \
		exit 1; \
	fi
	@export STELLAR_NETWORK=$(NETWORK) && \
	case $(NETWORK) in \
		pubnet) export HISTORY_ARCHIVE_URLS="https://history.stellar.org/prd/core-live/core_live_001/" ;; \
		testnet) export HISTORY_ARCHIVE_URLS="https://history.stellar.org/prd/core-testnet/core_testnet_001/" ;; \
		futurenet) export HISTORY_ARCHIVE_URLS="https://history.stellar.org/prd/core-futurenet/core_futurenet_001/" ;; \
		*) echo "Error: Invalid network. Use pubnet, testnet, or futurenet."; exit 1 ;; \
	esac && \
	docker compose up -d

down: ## Stop the stack
	@echo "Stopping Stellar Horizon..."
	docker compose down

restart: ## Restart the stack
	@echo "Restarting Stellar Horizon..."
	$(MAKE) down
	$(MAKE) up NETWORK=$(NETWORK)

logs: ## Follow logs
	docker compose logs -f horizon

health: ## Check health status
	@./scripts/health-check.sh

clean: ## Remove all data volumes (WARNING: destroys all data)
	@echo "WARNING: This will destroy all data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		echo "All data volumes removed."; \
	else \
		echo "Cancelled."; \
	fi

update: ## Update Horizon to latest version
	@echo "Pulling latest Horizon image..."
	docker compose pull horizon
	@echo "Running database migrations..."
	docker compose run --rm --entrypoint="" horizon horizon db migrate up
	@echo "Restarting Horizon..."
	$(MAKE) restart NETWORK=$(NETWORK)