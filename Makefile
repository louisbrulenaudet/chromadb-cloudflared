# Load the same keys docker compose uses from .env (optional until you copy .env.template)
-include .env

include make/variables.mk
include make/help.mk
include make/docker.mk

# Default target
.DEFAULT_GOAL := help
