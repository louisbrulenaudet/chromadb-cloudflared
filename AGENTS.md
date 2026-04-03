# Agent and contributor conventions

This file is the **authority** for the environment and port contract. Keep it in sync with [compose.yml](compose.yml), [.env.template](.env.template), and [README.md](README.md).

## Environment contract

Only these variables are referenced by Compose:

| Variable | Required for `docker compose` | Description |
|----------|-------------------------------|-------------|
| `CHROMA_DATA_DIR` | Yes | Absolute host path for ChromaDB data; bind-mounted to `/data` in the `chromadb` container. The directory must exist before startup. |
| `TUNNEL_TOKEN` | Yes | Cloudflare Tunnel token for `cloudflared` (`tunnel run`). |

Compose does **not** define default values for these. If either is missing or empty when Compose runs, substitution yields an empty value: the volume mount or tunnel authentication will misbehave or fail.

**Project `.env` file:** Docker Compose automatically loads a file named `.env` in the project directory for `${VAR}` substitution. Operators must copy [.env.template](.env.template) to `.env` and fill in real values before `docker compose up` or `make start`.

## Make vs Compose

The [Makefile](Makefile) uses `-include .env` and [make/variables.mk](make/variables.mk) may set `CHROMA_DATA_DIR` when `.env` is absent (for local convenience). **That default is not passed to Docker Compose.** Compose only reads the `.env` file in the project root (and the shell environment). Do not assume `make create-data-dir` and `make start` use the same `CHROMA_DATA_DIR` unless `.env` exists and defines it.

## Port and network contract

- **No published host ports** for `chromadb` or `cloudflared` in Compose.
- ChromaDB listens on `8000` only on the internal Docker network `backend` (service hostname `chromadb`).
- In the Cloudflare Zero Trust dashboard, the tunnel’s public hostname must target **`http://chromadb:8000`**, not `localhost` or a host IP (those resolve inside the `cloudflared` container, not the Chroma container).

## Healthcheck

The `chromadb` healthcheck uses `GET http://localhost:8000/api/v2/heartbeat` inside the container. `cloudflared` uses `depends_on` with `condition: service_healthy`.

## Changing configuration

Do not add new environment variables to [compose.yml](compose.yml) without updating [.env.template](.env.template) and this file.

## Security note

ChromaDB’s OSS server does not provide application-level API authentication suitable for exposing raw to the internet. Prefer a **Cloudflare Access** (or equivalent) policy on the tunnel’s public hostname so only authenticated clients reach the API.
