.PHONY: docker-check create-data-dir start stop restart logs clean

docker-check: ## Verify Docker and Docker Compose plugin are installed
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "❌ Docker is not installed! Please install it first."; \
		exit 1; \
	elif ! docker compose version >/dev/null 2>&1; then \
		echo "❌ Docker Compose plugin is not installed! Please install it first."; \
		exit 1; \
	else \
		echo "✅ Docker and Docker Compose are installed"; \
	fi

create-data-dir: ## Create CHROMA_DATA_DIR on the host (reads .env if present)
	@if [ -z "$(CHROMA_DATA_DIR)" ]; then \
		echo "❌ CHROMA_DATA_DIR is empty. Set it in .env (see .env.template) or export it, then retry."; \
		exit 1; \
	fi
	@echo "🔨 Creating data directory $(CHROMA_DATA_DIR)..."
	mkdir -p "$(CHROMA_DATA_DIR)"

start: ## Start chromadb and cloudflared (docker compose up -d)
	@if [ ! -f .env ]; then \
		echo "❌ Missing .env. Copy .env.template to .env and set CHROMA_DATA_DIR and TUNNEL_TOKEN."; \
		exit 1; \
	fi
	@echo "🚀 Starting services..."
	docker compose up -d

stop: ## Stop all compose services
	@echo "🛑 Stopping services..."
	docker compose down

restart: ## Restart all compose services
	@if [ ! -f .env ]; then \
		echo "❌ Missing .env. Copy .env.template to .env and set CHROMA_DATA_DIR and TUNNEL_TOKEN."; \
		exit 1; \
	fi
	@echo "🔄 Restarting services..."
	docker compose down && docker compose up -d

logs: ## Follow container logs
	@echo "📜 Showing logs..."
	docker compose logs -f

clean: ## Stop services and remove compose-managed volumes and orphans
	@echo "🧹 Cleaning up..."
	docker compose down --volumes --remove-orphans
