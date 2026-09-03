.PHONY: run build analyze compose help

GIT_COMMIT := $(shell git rev-parse --short=8 HEAD 2>/dev/null || echo "unknown")
GIT_TAG    := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")
BUILD_DATE := $(shell date -u +%Y-%m-%d)

default: help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nAvailable targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

run: ## Run the app locally. Runs the project directly. No image is built, neither is a container ran.
	@dotnet run --project src/Orders/Orders.csproj

analyze: ## Run dotnet analysis and local build. No image is built.
	@scripts/analyze.sh

compose: ## Runs docker compose to build and run the app locally in a container.
	@docker compose up

build: ## Build the application using the same script that is used for the CI build.
	@LOCAL=1 ./build/build.sh

start-db: ## Starts up just the database
	docker compose start orders_pg_db