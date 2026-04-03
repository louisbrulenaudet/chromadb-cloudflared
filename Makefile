# Make reads .env when present; docker compose also requires a project .env for compose.yml substitution.
-include .env

include make/variables.mk
include make/help.mk
include make/docker.mk

# Default target
.DEFAULT_GOAL := help
