# ChromaDB + Cloudflared Project Skill

## When to activate this skill

Activate this skill when the user is working on any of the following in this project:

- Modifying or reviewing `compose.yml` (or legacy `docker-compose.yml`)
- Configuring or troubleshooting the Cloudflare Tunnel (`cloudflared`)
- Managing ChromaDB collections, queries, or embeddings via the HTTP API
- Handling environment variables, secrets, or `.env` / `.env.template`
- Adding new services or changing the network topology
- Debugging healthcheck failures or startup sequencing issues
- Asking about data persistence, backup, or the ChromaDB data directory

## Project architecture

```
Internet
  └─► Cloudflare Edge  (HTTPS, public hostname with Access policy)
        └─► cloudflared container  (tunnel run, TUNNEL_TOKEN auth)
              └─► chromadb container  (http://chromadb:8000, internal only)
                    └─► /data  (bind-mounted from CHROMA_DATA_DIR on SSD)
```

**Key invariants — never violate these:**
- ChromaDB has **no published host ports**. It is only reachable inside the `backend` Docker bridge network.
- The Cloudflare Tunnel public hostname targets `http://chromadb:8000` — not `localhost`, not a host IP.
- `cloudflared` starts only after ChromaDB passes its healthcheck (`condition: service_healthy`).
- All secrets flow via `.env` → Docker Compose substitution. Nothing is hardcoded.

## Environment contract

| Variable | Required | Example | Notes |
|---|---|---|---|
| `CHROMA_DATA_DIR` | Yes | `/srv/chroma-data` | Host path, bind-mounted to `/data` in container. Must pre-exist. |
| `TUNNEL_TOKEN` | Yes | (from Zero Trust dashboard) | Cloudflare Tunnel token. Never commit. |

No other variables are used. All variables must appear in `.env.template` as placeholders.

## Port contract

| Service | Internal port | Host port |
|---|---|---|
| `chromadb` | `8000` | **none** |
| `cloudflared` | n/a | **none** |

## Healthcheck

- URL: `GET http://localhost:8000/api/v2/heartbeat`
- Expected response: HTTP 200 with `{"nanosecond heartbeat": <int>}`
- `curl` is available in `chromadb/chroma` images
- Timings: `interval: 30s`, `timeout: 10s`, `retries: 3`, `start_period: 20s`

## ChromaDB HTTP API reference (v2)

Base URL (from Cloudflare public hostname or internally): `http://chromadb:8000`

| Operation | Method | Path |
|---|---|---|
| Heartbeat | GET | `/api/v2/heartbeat` |
| List collections | GET | `/api/v2/tenants/{tenant}/databases/{db}/collections` |
| Create collection | POST | `/api/v2/tenants/{tenant}/databases/{db}/collections` |
| Get collection | GET | `/api/v2/tenants/{tenant}/databases/{db}/collections/{name}` |
| Add embeddings | POST | `/api/v2/tenants/{tenant}/databases/{db}/collections/{id}/add` |
| Query | POST | `/api/v2/tenants/{tenant}/databases/{db}/collections/{id}/query` |
| Delete collection | DELETE | `/api/v2/tenants/{tenant}/databases/{db}/collections/{name}` |

Default tenant: `default_tenant`. Default database: `default_database`.

## Cloudflare Tunnel configuration

- Auth method: `TUNNEL_TOKEN` environment variable → `command: tunnel run`
- Compose sets `TUNNEL_MANAGEMENT_DIAGNOSTICS=false` (opt out of remote management diagnostics per [cloudflared CHANGES](https://github.com/cloudflare/cloudflared/blob/master/CHANGES.md))
- Do not mount a `config.yml` or credentials file unless switching to file-based tunnel config
- In Zero Trust dashboard: Tunnels > your tunnel > Public Hostname > Service URL = `http://chromadb:8000`
- Recommended: add a Cloudflare Access application (policy) on the public hostname to require authentication before requests reach the tunnel

## Security baseline

- Both services: `security_opt: no-new-privileges:true`
- `chromadb`: `tmpfs: [/tmp]`, no published ports, bind mount for data
- Log rotation: `max-size: 10m`, `max-file: 3` on both services
- Cloudflare Access policy on the public hostname (enforced at Cloudflare edge). The Rust Chroma server **does not** provide built-in token/basic auth ([migration v1.0.0](https://docs.trychroma.com/docs/overview/migration)); do not suggest legacy `chroma_server_authn_*` / Python provider class names for the container.
- **Product telemetry:** use Chroma **≥ 1.5.4** ([Open Source — Telemetry](https://docs.trychroma.com/docs/overview/oss)). Do not set `CHROMA_OPEN_TELEMETRY__ENDPOINT` unless the operator wants OTLP traces ([Observability](https://docs.trychroma.com/guides/deploy/observability)).

## Common tasks and guidance

### First-time setup

```bash
# 1. Pre-create the data directory
sudo mkdir -p /srv/chroma-data

# 2. Copy and fill in secrets
cp .env.template .env
# Edit .env: set TUNNEL_TOKEN to your actual token

# 3. Start the stack
docker compose up -d

# 4. Check status
docker compose ps
docker compose logs -f
```

### Troubleshooting cloudflared not starting

`cloudflared` depends on `chromadb` being healthy. Check ChromaDB first:
```bash
docker compose logs chromadb
docker inspect chromadb --format='{{json .State.Health}}'
```

If ChromaDB is stuck unhealthy, curl the heartbeat from inside the container:
```bash
docker exec chromadb curl -sf http://localhost:8000/api/v2/heartbeat
```

### Updating ChromaDB version

1. Change the image tag in `compose.yml` (e.g. `chromadb/chroma:1.6.0`)
2. Verify the healthcheck endpoint still works on the new version
3. Test locally before deploying: `docker compose pull && docker compose up -d`

### Application-level token in front of Chroma

The single-node Rust server does not implement Chroma’s old Python token providers. For a header/API token, the supported patterns are **Cloudflare Access** (edge) or a **separate proxy service** on `backend` that validates tokens and forwards to `http://chromadb:8000`.

## What this skill must always enforce

When suggesting changes to this project:

1. Never add `ports:` to `chromadb` — redirect users to use the Cloudflare Tunnel instead.
2. Never suggest `network_mode: host` — it bypasses network isolation.
3. Always remind users to pre-create `CHROMA_DATA_DIR` before `docker compose up`.
4. Always validate that tunnel public hostname points to `http://chromadb:8000` (Docker DNS), not `localhost`.
5. Treat `TUNNEL_TOKEN` as a secret — never echo it, never suggest committing it.
6. When modifying `compose.yml`, ensure both `CHROMA_DATA_DIR` and `TUNNEL_TOKEN` remain in `.env.template`.
7. For ChromaDB API v2, use `/api/v2/` prefix — not `/api/v1/`.
