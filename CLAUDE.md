# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Kubernetes deployment configurations for SYNQ Scout AI, a service that requires access to Claude models through an OpenAI-compatible API (typically via LiteLLM proxy). SYNQ Scout has been tested with LiteLLM v1.77.5-stable.

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
kubectl logs -l deployment=synq-scout

# Test configuration and LLM connectivity
synq-scout health
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
  - `agent.env`: Environment variables for secrets (SYNQ_CLIENT_ID, SYNQ_CLIENT_SECRET, OPENAI_API_KEY)
  - `kustomization.yaml`: Base kustomization with ConfigMap and Secret generators

- **`overlays/`**: Environment-specific configurations
  - `example/`: Example environment with namePrefix "example-"
  - `synq-staging/`: Staging environment
  - Each overlay merges its own `agent.yaml` and `agent.env` with base configurations

### Configuration Architecture

**Configuration is split into two layers:**

1. **ConfigMap** (`synq-scout-agent-config`): Generated from `agent.yaml`, contains:
   - SYNQ client credentials (referenced from environment variables)
   - Data warehouse connections
   - LLM settings (base_url, api_key, thinking_model, summary_model)

2. **Secret** (`synq-scout-agent-env`): Generated from `agent.env`, contains:
   - `SYNQ_CLIENT_ID`: Client ID from SYNQ
   - `SYNQ_CLIENT_SECRET`: Client secret from SYNQ
   - `OPENAI_API_KEY`: API key for LiteLLM proxy

The deployment mounts the ConfigMap at `/opt/synq-scout/` and injects Secret values as environment variables.

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
  - **Recommended**: `claude-4-5-sonnet` (latest, best quality, still under review but no known issues) or `claude-4-sonnet` (stable, production-ready)
- `summary_model`: Used for summaries
  - **Recommended**: `claude-4-5-sonnet` or `claude-4-sonnet` for best quality, or `claude-3-5-haiku` for cost optimization
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

Current version in deployment: `v0.1.7`
