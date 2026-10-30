# CLAUDE.md

This file gives instructions to Claude Code (claude.ai/code) for this repository.

## Repository overview

This repository deploys Coalesce Quality Scout on Kubernetes. It uses Kustomize with a base and overlays. Scout uses Claude models through an OpenAI-compatible API, usually a LiteLLM proxy. We tested Scout with LiteLLM v1.77.5-stable.

The repository is public. Do not put customer names or real credentials in it.

- Configuration schema: https://schemas.synq.io/synq-scout/v1/config.html
- Releases and the full configuration example: https://github.com/getsynq/synq-scout. Read the release notes before you change the image version. Compare `base/agent.yaml` with `agent.example.yaml` in that repository.

## Layout

- `base/deployment.yaml`: The Scout deployment, with the Keel annotations. It mounts the ConfigMap at `/opt/synq-scout/` and loads the Secret as environment variables.
- `base/agent.yaml`: The Scout configuration. It has the LLM settings and an example of each common connection type.
- `base/agent.env`: A placeholder for each secret. `QUALITY_CLIENT_ID` and `QUALITY_CLIENT_SECRET` are empty, so the overlay sets the real values.
- `base/kustomization.yaml`: Generates the `synq-scout-agent-config` ConfigMap and the `synq-scout-agent-env` Secret. The namespace is `synq`.
- `overlays/example/`: The example overlay. It uses the `example-` name prefix and sets `disableNameSuffixHash: true`.
- `synq-scout-example.yaml`: The example overlay, built into one file by `./build.sh`.
- `keel.yaml`: The Keel deployment, built from `keel-values.yaml` and `keel-template.yaml` by `./keel.sh`.

Git ignores everything in `overlays/` except the `example` overlay. Other overlays, for example `synq-staging`, exist only on the local disk.

An overlay's `agent.yaml` replaces `base/agent.yaml` as a whole. Kustomize does not merge the two files. An overlay's `agent.env` is merged with `base/agent.env` key by key.

Because of `disableNameSuffixHash: true`, a change to the ConfigMap or the Secret does not restart the pod.

## Commands

```bash
# Build synq-scout-example.yaml
./build.sh

# Deploy
kubectl apply -k overlays/example
kubectl apply -f synq-scout-example.yaml

# Verify
kubectl -n synq get deployments
kubectl -n synq get pods
kubectl -n synq logs -l deployment=synq-scout
kubectl -n synq exec deploy/example-synq-scout-deployment -- synq-scout health

# Build keel.yaml
./keel.sh
```

`docker-compose.yml` is for local tests only. Do not use it in production.

## Environment variables

- `QUALITY_CLIENT_ID` and `QUALITY_CLIENT_SECRET`: The Coalesce Quality credentials. Scout also reads `SYNQ_CLIENT_ID` and `SYNQ_CLIENT_SECRET`. If both names are set, the `QUALITY_` name is used.
- `OPENAI_API_KEY`: The API key for LiteLLM.
- `VALIDATE_CONNECTIONS` (default `true`): Test each connection when Scout starts.
- `REQUIRE_VALID_CONNECTIONS` (default `false`): Stop the start if a connection test fails.
- `REQUIRE_CONTROL_PLANE` (default `false`): Stop the start if the control plane configuration is not available after 3 tries.
- `LOG_FORMAT` (default `json`), `LOG_ADD_SOURCE` (default `true`), `LOG_LEVEL` (default `INFO`): Logging.

## Connections

- The key of each connection is the integration ID from Coalesce Quality. Use a UUID.
- `name`, `disabled` and `parallelism` are optional. The default of `parallelism` is `8`.
- Users generate connections at https://app.synq.io/settings/scout. The README recommends this method.
- Secrets in `agent.yaml` are environment variable references, for example `${POSTGRES_PASSWORD}`. The values are in `agent.env`.
- Supported types: PostgreSQL, MySQL, BigQuery, ClickHouse, Snowflake, Redshift, Databricks, Trino, SQL Server, Oracle, Athena, Fabric, Db2. DuckDB is not supported.
- Snowflake uses private key authentication, inline (`private_key`) or as a file (`private_key_file`). Password authentication is deprecated.

## Models

- `thinking_model`: `claude-5-5-sonnet`. `claude-5-5-opus` also works, at a higher cost.
- `summary_model`: `claude-5-5-haiku`, or `claude-5-5-sonnet` to use one model.
- If `thinking_model` is not set, Scout uses `claude-4-6-sonnet`.
- The LiteLLM `model_name` of each model must be the same as the value in `agent.yaml`.

## Image versions

- The image is `europe-docker.pkg.dev/synq-cicd-public/synq-public/synq-scout`. The current version is in `base/deployment.yaml`.
- The `upgrade-version.yaml` workflow opens a PR when the registry has a new stable version.
- If you change the image version, run `./build.sh` to update `synq-scout-example.yaml`.
