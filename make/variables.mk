# make/variables.mk

# Defaults only if unset (shell env, .env include, or earlier makefile).
# Use $HOME so macOS (read-only /srv) and Linux desktops work without .env; Pi/production sets /srv/chroma-data in .env.
CHROMA_DATA_DIR ?= $(HOME)/chroma-data
PROJECT_NAME ?= chromadb-cloudflared

# Colors for formatting
BLUE := \033[1;34m
CYAN := \033[1;36m
WHITE := \033[1;37m
RESET := \033[0m
