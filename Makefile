.PHONY: local build analyze start stop help

GIT_COMMIT := $(shell git rev-parse --short=8 HEAD 2>/dev/null || echo "unknown")
GIT_TAG    := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")
BUILD_DATE := $(shell date -u +%Y-%m-%d)

default: help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nAvailable targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

run: ## Run the app locally
	dotnet run --project src/Orders/Orders.csproj

compose:
	docker compose up

build: ## Build the application
	LOCAL=1 ./build/build.sh