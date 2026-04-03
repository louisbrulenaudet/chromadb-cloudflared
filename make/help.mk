# Define help sections
define HELP_HEADER
$(BLUE)$(PROJECT_NAME) Docker Commands$(RESET)

$(WHITE)Usage:$(RESET)
    make [command]

$(WHITE)Available Commands:$(RESET)
$(CYAN)    %-20s %s$(RESET)
    %-20s %s

endef
export HELP_HEADER

define HELP_EXAMPLES
$(WHITE)Examples:$(RESET)
    make create-data-dir   # mkdir -p CHROMA_DATA_DIR (from .env or default)
    make start             # Start chromadb and cloudflared
    make stop              # Stop chromadb and cloudflared
    make restart           # Restart chromadb and cloudflared
    make logs              # Follow container logs
    make clean             # Stop services and remove compose-managed volumes and orphans

endef
export HELP_EXAMPLES

# Help command implementation
help:
	@printf "$$HELP_HEADER" "Command" "Description" "-------" "-----------"
	@awk 'BEGIN {FS = ":.*##"} \
		/^[a-zA-Z_-]+:.*?##/ { \
			printf "    \033[36m%-20s\033[0m %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)
	@printf "\n$$HELP_EXAMPLES"
