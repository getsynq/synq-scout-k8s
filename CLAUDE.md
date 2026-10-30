# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Kubernetes deployment configurations for Coalesce Quality Scout, a service that requires access to Claude models through an OpenAI-compatible API (typically via LiteLLM proxy). Coalesce Quality Scout has been tested with LiteLLM v1.77.5-stable.

**Official Documentation**: https://schemas.synq.io/synq-scout/v1/config.html

**Releases and the full configuration example**: https://github.com/getsynq/synq-scout. Read its release notes before you bump the image, and check `base/agent.yaml` against its `agent.example.yaml`.

## Build and Deployment Commands

### Generate Kubernetes Manifests

```bash
# Build the example manifest from Kustomize overlay
make build
# or directly:
./build.sh
```

This generates `synq-scout-example.yaml` from the Kustomize overlay.

### Deploy to Kubernetes

```bash
# Using Kustomize (recommended)
kubectl apply -k overlays/example

# Direct deployment
kubectl apply -f synq-scout-example.yaml
```

### Verify Deployment

```bash
# Check deployment status
kubectl get deployments

# Check pods
kubectl get pods

# View logs
kubectl -n synq logs -l deployment=synq-scout

# Test configuration and LLM connectivity, inside the running pod
kubectl -n synq exec deploy/example-synq-scout-deployment -- synq-scout health
```

### Generate Keel Manifest

```bash
# Generate keel.yaml from template
./keel.sh
```

This uses `keel-template.yaml` and `keel-values.yaml` with Go templating.

## Architecture

### Kustomize Structure

The project uses **Kustomize** for environment-based configuration management:

- **`base/`**: Contains base Kubernetes resources
  - `deployment.yaml`: Deployment with Keel annotations for auto-updates
  - `agent.yaml`: Agent configuration with LLM settings (thinking_model and summary_model)
  - `agent.env`: Environment variables for secrets (QUALITY_CLIENT_ID, QUALITY_CLIENT_SECRET, OPENAI_API_KEY)
  - `kustomization.yaml`: Base kustomization with ConfigMap and Secret generators

- **`overlays/`**: Environment-specific configurations
  - `example/`: Example environment with namePrefix "example-"
  - An overlay's `agent.yaml` replaces the base file as a whole. Its `agent.env` is merged key by key with the base one.

### Configuration Architecture

**Configuration is split into two layers:**

1. **ConfigMap** (`synq-scout-agent-config`): Generated from `agent.yaml`, contains:
   - Coalesce Quality client credentials (`QUALITY_CLIENT_ID` / `QUALITY_CLIENT_SECRET`, referenced from environment variables)
   - Data warehouse connections
   - LLM settings (base_url, api_key, thinking_model, summary_model)

2. **Secret** (`synq-scout-agent-env`): Generated from `agent.env`, contains:
   - `QUALITY_CLIENT_ID`: Client ID from Coalesce Quality (`SYNQ_CLIENT_ID` is still read as a fallback)
   - `QUALITY_CLIENT_SECRET`: Client secret from Coalesce Quality (`SYNQ_CLIENT_SECRET` is still read as a fallback)
   - `OPENAI_API_KEY`: API key for LiteLLM proxy
   - `VALIDATE_CONNECTIONS` (optional): Enable/disable connection validation on startup (default: true)
   - `REQUIRE_VALID_CONNECTIONS` (optional): Make validation failures fatal (default: false)
   - `REQUIRE_CONTROL_PLANE` (optional): Make control plane config retrieval failures fatal (default: false, retries 3 times with exponential backoff)
   - `LOG_FORMAT` (optional): Logging output format - `json` (default) or `text`
   - `LOG_ADD_SOURCE` (optional): Include source file location in logs - `true` (default) or `false`
   - `LOG_LEVEL` (optional): Minimum log level - `DEBUG`, `INFO` (default), `WARN`, or `ERROR`

The deployment mounts the ConfigMap at `/opt/synq-scout/` and injects Secret values as environment variables.

### Database Connection Configuration

Database connections are defined in the `connections` section of `agent.yaml`. Each connection configuration includes:

**Fields**:
- **Connection ID** (required): A string identifier that should match the integration ID from Coalesce Quality
  - UUIDs are strongly recommended (e.g., `"52467b4f-cbab-4255-8cfc-07a11a726855"`) as they improve deterministic agent behavior
  - Other string identifiers can be used but may affect consistency
- **name** (optional): Human-readable connection name
  - Defaults to connection ID if not specified
- **disabled** (optional): Boolean flag (`false` to enable, `true` to disable)
  - Defaults to `false` (enabled) if not specified
- **parallelism** (optional): Number of parallel queries
  - Defaults to `8` if not specified (suitable for medium/large warehouses)
  - Small warehouses / development: `1-2` (override default)
  - Medium warehouses: `4-8` (default is appropriate)
  - Large warehouses: `8-16` (default or higher)
  - Serverless/autoscaling warehouses: `16+` to leverage automatic scaling
- **Database-specific config** (required): Credentials and connection details for the specific database type

**Recommended Approach**: Use the Coalesce Quality UI to auto-generate connection configurations at https://app.synq.io/settings/scout. This ensures:
- Connection IDs match Coalesce Quality integration IDs
- UUIDs are used for deterministic behavior
- All required fields are included with proper structure

**Credential Management**:
- Use environment variable references (e.g., `${POSTGRES_PASSWORD}`) in `agent.yaml` for all sensitive credentials
- Define actual credential values in `agent.env` files
- Environment variables from `agent.env` are injected into the container via Kubernetes Secrets

**Supported Databases**: PostgreSQL, MySQL, BigQuery, ClickHouse, Snowflake, Redshift, Databricks, Trino, SQL Server, Oracle, Athena, Fabric, Db2. DuckDB is not supported.

**Snowflake Authentication**: Snowflake supports two methods for private key authentication (password auth is deprecated):
- **Inline private key**: Store PEM content in environment variable (`private_key: ${SNOWFLAKE_PRIVATE_KEY}`)
- **Private key file**: Store path to mounted secret file (`private_key_file: "/opt/secrets/snowflake-private-key.pem"`)
- Both methods support encrypted keys via optional `private_key_passphrase` parameter

**MySQL Configuration**: Supports `database` parameter, `allow_insecure` flag for non-TLS connections, and custom connection parameters via `params` map.

See `base/agent.yaml` for configuration examples of the most common database types.

### Container Image Auto-Updates with Keel

The deployment includes Keel annotations for automatic container updates:

```yaml
annotations:
  keel.sh/policy: minor
  keel.sh/trigger: poll
  keel.sh/pollSchedule: "@every 1m"
```

Deploy Keel using `kubectl apply -f keel.yaml`.

### LLM Model Configuration

Models are configured in `base/agent.yaml`:
- `thinking_model`: Used for complex reasoning
  - **Recommended**: `claude-5-5-sonnet`. `claude-5-5-opus` also works, at a higher cost.
- `summary_model`: Used for summaries
  - **Recommended**: `claude-5-5-haiku`, or `claude-5-5-sonnet` to configure one model
- Both models must be available through the LiteLLM proxy at the configured `base_url`

Models can be overridden per environment in overlay `agent.yaml` files.

**Tested LiteLLM Version**: v1.77.5-stable

## Important Configuration Notes

- **Namespace**: Default namespace is `synq` (defined in base kustomization)
- **Name Prefix**: Overlays can add name prefixes (e.g., `example-` in example overlay)
- **Generator Options**: `disableNameSuffixHash: true` is set in overlays to prevent hash suffixes on ConfigMaps/Secrets
- **Secret Management**: Never commit actual credentials to git. The `overlays/` directory is gitignored to prevent accidental secret commits
- **Docker Compose**: A `docker-compose.yml` exists for local development but is NOT recommended for production

## Container Registry

Images are hosted at: `europe-docker.pkg.dev/synq-cicd-public/synq-public/synq-scout`

Current version: See `base/deployment.yaml` (auto-updated on releases)
