# Review Configuration Command

Run a **configuration-focused** review of the `chromadb-cloudflared` project: secrets handling, Docker Compose correctness, healthcheck integrity, network isolation, and env/template parity. Your reply must be a **plan of suggested changes**: concise, actionable, and structured — not only prose.

## Cursor command usage

This file is a [Cursor custom command](https://docs.cursor.com/context/commands): plain Markdown in `.cursor/commands/`. When the user runs `/review-configuration` in chat, this content is sent as the prompt.

- **Parameters:** Any text after `/review-configuration` narrows scope — e.g. `/review-configuration secrets`, `/review-configuration healthcheck`, `/review-configuration network`, `/review-configuration compose`. If none given, assume a full configuration review.

This command is project-scoped and works with `@` mentions and Rules. Align with `AGENTS.md` for env and port contract guidance.

## Best practices alignment

- **Secrets** — Never committed, never embedded in build artifacts. Real values flow via `.env` only. `.env.template` must be placeholder-only.
- **Environment contract** — Only two required variables: `CHROMA_DATA_DIR` and `TUNNEL_TOKEN`. No silent empty defaults.
- **Port contract** — ChromaDB has no published host ports. Only `cloudflared` reaches it via the `backend` Docker network.
- **Healthcheck** — Must target `/api/v2/heartbeat` on `http://localhost:8000`. `cloudflared` depends on `service_healthy`.
- **Network isolation** — ChromaDB is only reachable from inside the `backend` Docker network. The tunnel target must be `http://chromadb:8000`.
- **Image pinning** — `chromadb/chroma` must be version-pinned; `cloudflare/cloudflared:latest` is acceptable.
- **Security baseline** — Both services use `no-new-privileges:true`. ChromaDB uses `tmpfs` for `/tmp`. Log rotation is bounded.

## Deep technical review

Conduct a configuration-only review. Inspect the following and call out violations or improvements.

### Secrets and environment

- **Artifacts:** `.env.template`, `.env` (must exist locally, must be gitignored), `.gitignore`, `.dockerignore`, `compose.yml`
- **Checks:**
  - `.env.template` lists both required variables with placeholder values only (no real secrets).
  - `.env` is listed in `.gitignore` — real secrets are never committed.
  - `.dockerignore` covers `.env` and `.env.*` — no secrets can leak into a future image build context.
  - `compose.yml` references `${CHROMA_DATA_DIR}` and `${TUNNEL_TOKEN}` without hardcoded fallbacks.
  - `TUNNEL_TOKEN` is injected via `environment:`, not `env_file:` directly into the service (correct pattern for tunnel auth).
- **Anti-patterns to flag:**
  - Hardcoded token or path values in `compose.yml`.
  - `.env` present in `.git` history.
  - Missing `.env*` coverage in `.dockerignore`.

### Docker Compose correctness

- **Artifacts:** `compose.yml`
- **Checks:**
  - `chromadb` image tag is at least `1.5.4` if the goal is “no Chroma product telemetry” ([Open Source — Telemetry](https://docs.trychroma.com/docs/overview/oss)).
  - No accidental `CHROMA_OPEN_TELEMETRY__ENDPOINT` unless the operator wants OTLP traces ([Observability](https://docs.trychroma.com/guides/deploy/observability)).
  - `chromadb` has **no `ports:` mapping** — host network exposure is forbidden per `AGENTS.md`.
  - `cloudflared` has **no `ports:` mapping** — it is outbound only.
  - `depends_on` uses `condition: service_healthy` (not just `service_started`).
  - Both services are on the `backend` network and only the `backend` network.
  - `networks.backend.driver` is `bridge`.
  - Volume mapping uses `${CHROMA_DATA_DIR}:/data` (bind mount, not named volume).
  - Both services have `restart: unless-stopped`.
  - Both services have bounded log rotation (`max-size`, `max-file`).
  - Both services have `security_opt: no-new-privileges:true`.
  - `chromadb` has `init: true` and `tmpfs: [/tmp]`.
- **Anti-patterns to flag:**
  - `ports: 8000:8000` or any host port mapping on `chromadb`.
  - `depends_on: chromadb` without `condition: service_healthy`.
  - Named Docker volume instead of bind mount for ChromaDB data.
  - Missing security hardening options.

### Healthcheck integrity

- **Artifacts:** `compose.yml` (healthcheck block under `chromadb`)
- **Checks:**
  - Test command: `curl -f http://localhost:8000/api/v2/heartbeat` — endpoint and port must match exactly.
  - `curl` is available in the `chromadb/chroma` image (it is — verify if image version changes).
  - Timings are reasonable for a Raspberry Pi: `start_period` ≥ 20s, `interval` ≥ 30s.
  - `retries: 3` is sufficient before marking unhealthy.
- **Anti-patterns to flag:**
  - Using `wget` or `python` instead of `curl` if `curl` is not present in the image.
  - Healthcheck pointing at wrong path (e.g. `/api/v1/heartbeat` instead of `/api/v2/heartbeat`).
  - `start_period` too short for Pi cold-start (ChromaDB can take 10–15s to initialize).

### Cloudflare Tunnel configuration

- **Artifacts:** `compose.yml` (cloudflared service)
- **Checks:**
  - `command: tunnel run` is correct for token-based tunnel auth.
  - `TUNNEL_TOKEN` is supplied via environment (no token baked into the image). Optional: `TUNNEL_MANAGEMENT_DIAGNOSTICS: "false"` to opt out of remote management diagnostics ([cloudflared release notes](https://github.com/cloudflare/cloudflared/blob/master/CHANGES.md)).
  - The tunnel's public hostname in Cloudflare Zero Trust dashboard targets `http://chromadb:8000` (not `localhost`, not a host IP).
  - A Cloudflare Access policy is recommended on the public hostname to require authentication (Rust Chroma has no built-in server auth per [migration v1.0.0](https://docs.trychroma.com/docs/overview/migration)).
- **Anti-patterns to flag:**
  - Using `tunnel --url` flag instead of `tunnel run` with a token.
  - Tunnel targeting `localhost:8000` or `127.0.0.1:8000` (these resolve to the cloudflared container, not chromadb).
  - No Access policy protecting the public hostname.

### Network isolation

- **Artifacts:** `compose.yml` (networks block, per-service networks)
- **Checks:**
  - Only one network (`backend`) is defined.
  - Both services declare only `backend` under `networks:`.
  - No `network_mode: host` on any service.
  - ChromaDB is not reachable from the Docker host via any published port.
- **Anti-patterns to flag:**
  - `network_mode: host` on either service.
  - Additional networks that would give chromadb external reachability.

### Template and gitignore parity

- **Artifacts:** `.env.template`, `.gitignore`, `.dockerignore`
- **Checks:**
  - Every variable used in `compose.yml` appears in `.env.template`.
  - `.gitignore` covers `.env`, `.env.local`, `.env.*.local`.
  - `.dockerignore` covers `.env`, `.env.*` (with `!.env.template` exception if desired).
  - No variable is used in compose but absent from the template.

## Steps

1. **Gather scope** — Full review or narrowed scope if a parameter was provided.
2. **Inspect secrets and env** — `.env.template` placeholder-only, `.gitignore`/`.dockerignore` coverage, no hardcoded values in compose.
3. **Inspect Compose correctness** — No host ports, `service_healthy` dependency, volume mapping, security options, log rotation.
4. **Inspect healthcheck** — Correct endpoint, correct port, appropriate timings for Raspberry Pi.
5. **Inspect Cloudflare Tunnel** — `tunnel run` command, token injection, tunnel target URL, Access policy recommendation.
6. **Inspect network isolation** — Single `backend` bridge, no host-mode, no external reachability for ChromaDB.
7. **Check template parity** — All compose variables present in `.env.template`.
8. **Compose plan** — Output **Critical / Improvements / Optional** with **what/where/why**. State "no issues" for any sub-area with no findings.

## Checklist

- [ ] Scope clear
- [ ] Secrets reviewed (`.env.template`, `.gitignore`, `.dockerignore`, `compose.yml`)
- [ ] Compose correctness reviewed (ports, depends_on condition, volumes, security options, log rotation)
- [ ] Healthcheck reviewed (endpoint, port, timings)
- [ ] Cloudflare Tunnel reviewed (command, token, tunnel target URL)
- [ ] Network isolation reviewed (backend only, no host ports, no host-mode networking)
- [ ] Template parity reviewed (all compose vars in `.env.template`)
- [ ] Output structured as Critical / Improvements / Optional with what/where/why

## Context usage

Use `@` mentions for these files:
- `compose.yml` — primary artifact
- `.env.template` — env contract reference
- `.gitignore` and `.dockerignore` — secrets exclusion coverage
- `AGENTS.md` — port and env contract authority

Use `@git` to check recent configuration changes for quality regressions.

If context is insufficient, suggest which files to add via `@file`.

## Output format

Respond with a **plan only** (no implementation unless the user asks):

1. **Critical** — Must-fix (breaks runtime, exposes secrets, or violates network isolation).
2. **Improvements** — Worthwhile (better resilience, clearer contract, alignment with `AGENTS.md`).
3. **Optional** — Nice-to-haves. Prefix with **Nit:** for non-blocking polish.

For each item: **what** to change, **where** (file/section), and **why**. State "no issues" in one line for any sub-area with no findings.
