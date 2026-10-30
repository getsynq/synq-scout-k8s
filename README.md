# Coalesce Quality Scout on Kubernetes

This repository deploys Coalesce Quality Scout on Kubernetes. Scout connects to your data warehouses and uses Claude models to triage and analyse data quality issues.

This repository only holds the Kubernetes recipe. The Scout releases, the CLI and the full configuration example are in [getsynq/synq-scout](https://github.com/getsynq/synq-scout):

- [Releases](https://github.com/getsynq/synq-scout/releases) tell what changed in each version.
- [agent.example.yaml](https://github.com/getsynq/synq-scout/blob/main/agent.example.yaml) shows every connection type.
- The CLI reference is at <https://docs.synq.io/scout/cli>.

You can deploy Scout in two ways:

1. With Kustomize, from an overlay in `overlays/`. We recommend this method.
2. With `kubectl apply` and the generated `synq-scout-example.yaml` file.

## Quick start

```bash
# With Kustomize
kubectl apply -k overlays/example

# OR with the generated file
kubectl apply -f synq-scout-example.yaml
```

The `example` overlay connects to a test PostgreSQL database and uses example credentials. Change both before you use it.

## Prerequisites

- Access to a Kubernetes cluster.
- `kubectl` v1.14 or later, which includes Kustomize.
- API credentials from Coalesce Quality. Create them under Settings → API in your workspace.
- An OpenAI-compatible API that serves Claude models. We recommend [LiteLLM](https://docs.litellm.ai/) v1.77.5-stable or later as a proxy. See [Set up LiteLLM](#set-up-litellm).

The Scout image is public and is available for amd64 and arm64, so you do not need registry credentials.

## Repository layout

```
synq-scout-k8s/
├── base/                    # Resources that all overlays share
│   ├── deployment.yaml      # The Scout deployment
│   ├── kustomization.yaml   # Generates the ConfigMap and the Secret
│   ├── agent.yaml           # Scout configuration, with an example of each connection type
│   └── agent.env            # Environment variables, with a placeholder for each secret
├── overlays/
│   └── example/             # Example overlay, copy it for your own environment
└── synq-scout-example.yaml  # The example overlay, built into one file
```

Git ignores everything in `overlays/` except the `example` overlay. Thus your own overlay and its secrets stay out of Git.

## Set up LiteLLM

Scout sends its requests to an OpenAI-compatible API. LiteLLM gives this API for Claude models. Deploy LiteLLM as a separate service in your cluster. Follow the [LiteLLM Kubernetes guide](https://docs.litellm.ai/docs/proxy/deploy#kubernetes). The guide deploys a ConfigMap, a Secret, a Deployment and a Service.

The LiteLLM configuration has two model names for each model:

- `model_name` is the name that Scout requests. It must be the same as `thinking_model` or `summary_model` in `agent.yaml`.
- `litellm_params.model` is the name that your provider uses for the model. It is different for each provider.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-config-file
data:
  config.yaml: |
    model_list:
       - model_name: claude-5-5-sonnet        # what Scout requests
         litellm_params:
           model: <your-provider-model-id>    # e.g. anthropic/..., vertex_ai/..., bedrock/...
           api_key: os.environ/ANTHROPIC_API_KEY
       - model_name: claude-5-5-haiku
         litellm_params:
           model: <your-provider-model-id>
           api_key: os.environ/ANTHROPIC_API_KEY
```

Claude is available from the Anthropic API, Google Vertex AI (`vertex_ai/` prefix) and Amazon Bedrock (`bedrock/` prefix). Each provider has its own model identifiers and credentials. Get them from the [LiteLLM provider documentation](https://docs.litellm.ai/docs/providers).

We tested Scout with LiteLLM v1.77.5-stable. In production, use a versioned LiteLLM image tag, for example `v1.77.5-stable`. Do not use `main-stable`.

When LiteLLM runs, set `llm.openai.base_url` in your `agent.yaml` to the URL of the LiteLLM service. The example overlay uses `http://litellm-service.litellm.svc.cluster.local:4000/v1/chat/completions`.

## Models

Scout uses two models:

| Setting | Model | Use |
|---|---|---|
| `thinking_model` | `claude-5-5-sonnet` (Claude Sonnet 5.5) | Reasoning, triage and analysis |
| `summary_model` | `claude-5-5-haiku` (Claude Haiku 5.5) | Summaries and reports. Haiku is faster and cheaper than Sonnet, and summaries do not need Sonnet. |

This repository uses these models. If you want to configure only one model, set `summary_model` to `claude-5-5-sonnet` too.

You can also use `claude-5-5-opus` as the thinking model, at a higher cost, or the previous models `claude-4-6-sonnet` and `claude-4-5-haiku`. If you do not set `thinking_model`, Scout uses `claude-4-6-sonnet`, so always set it. The names include a version, so the model does not change when a new version is released.

Scout does not support OpenAI models. Google Gemini models are not ready, and we do not recommend them.

Set the models in the `llm.openai` section of your overlay's `agent.yaml`.

## Deploy with Kustomize

1. Copy `overlays/example` to a new directory, for example `overlays/production`.
2. In the new `agent.env`, set `QUALITY_CLIENT_ID`, `QUALITY_CLIENT_SECRET` and `OPENAI_API_KEY`.
3. In the new `agent.env`, add the passwords and keys that your connections use.
4. In the new `agent.yaml`, set the LiteLLM URL and define your connections. See [Connections](#connections).
5. Deploy the overlay:

   ```bash
   kubectl apply -k overlays/production
   ```

## Deploy with the generated file

`synq-scout-example.yaml` is the `example` overlay, built into one file. Use it if you do not want to use Kustomize.

1. Edit the ConfigMap and the Secret in `synq-scout-example.yaml`.
2. Deploy the file:

   ```bash
   kubectl apply -f synq-scout-example.yaml
   ```

To build the file again from the overlay, run `./build.sh`.

## Verify the deployment

```bash
kubectl -n synq get deployments
kubectl -n synq get pods
kubectl -n synq logs -l deployment=synq-scout

# Test the configuration and the LLM connection, inside the running pod
kubectl -n synq exec deploy/example-synq-scout-deployment -- synq-scout health
```

Use your own name prefix instead of `example-`.

`synq-scout health` checks the configuration. It also connects to the Coalesce Quality control plane, to each data warehouse connection, and to the thinking and summary models.

## Configuration

Scout reads its configuration from `agent.yaml`. The schema is documented at https://schemas.synq.io/synq-scout/v1/config.html.

An overlay's `agent.yaml` replaces `base/agent.yaml` as a whole. Kustomize does not merge the two files. Scout reads `QUALITY_CLIENT_ID`, `QUALITY_CLIENT_SECRET` and `OPENAI_API_KEY` from the environment, so an overlay `agent.yaml` does not need the `synq` section or `llm.openai.api_key`.

The example overlay sets `disableNameSuffixHash: true`, so a change to `agent.yaml` or `agent.env` does not restart the pod. After a change, restart the deployment:

```bash
kubectl -n synq rollout restart deployment/example-synq-scout-deployment
```

### Connections

Define the data warehouse connections in the `connections` section of `agent.yaml`. We recommend that you generate them at https://app.synq.io/settings/scout. The generated configuration uses the correct connection IDs and includes all required fields.

Each connection has these fields:

| Field | Required | Description |
|---|---|---|
| Connection ID | Yes | The key of the connection. Use the ID of the integration in Coalesce Quality, so Scout can map the connection to its data. Use a UUID, as it makes the behavior of Scout more deterministic. |
| `name` | No | A name for people to read. The default is the connection ID. |
| `disabled` | No | If `true`, Scout does not use the connection. The default is `false`. |
| `parallelism` | No | The maximum number of queries that run at the same time on the connection. The default is `8`. |
| Connection type | Yes | The block for the warehouse type, for example `postgres` or `snowflake`, with the connection details. |

If you write a connection manually:

1. Get the ID of the integration in Coalesce Quality.
2. Add the block for the warehouse type.
3. Refer to secrets with environment variables, for example `password: ${POSTGRES_PASSWORD}`.
4. Set these variables in your overlay's `agent.env`.

`base/agent.yaml` has an example of each common connection type.

### Parallelism

The default of `8` is correct for most medium and large warehouses. Use these values as a guide:

| Warehouse | `parallelism` |
|---|---|
| Small, or development | 1 to 2 |
| Medium | 4 to 8 |
| Large | 8 to 16 |
| Serverless or autoscaling | 16 or more |

### Supported connections

Scout connects to PostgreSQL, MySQL, BigQuery, ClickHouse, Snowflake, Redshift, Databricks, Trino, SQL Server, Oracle, Amazon Athena, Microsoft Fabric and IBM Db2 (Linux, UNIX and Windows). Scout cannot connect to DuckDB. [agent.example.yaml](https://github.com/getsynq/synq-scout/blob/main/agent.example.yaml) shows the fields of each type.

### BigQuery without a key

A BigQuery connection can use `impersonate_service_accounts` instead of a service account key. Scout starts with the Application Default Credentials of the pod, for example a GKE workload identity. Then it impersonates the listed service accounts in order. Each service account must grant `roles/iam.serviceAccountTokenCreator` to the identity before it. See Example 3B in `base/agent.yaml`.

### Snowflake

Use private key authentication. Snowflake password authentication is deprecated. You can give the key in two ways:

- Inline: set `private_key: ${SNOWFLAKE_PRIVATE_KEY}` in `agent.yaml`, and put the PEM content in `SNOWFLAKE_PRIVATE_KEY` in `agent.env`.
- As a file: set `private_key_file: "/opt/secrets/snowflake-private-key.pem"` in `agent.yaml`, and mount the key from a Kubernetes Secret at that path. The deployment does not mount it, so add a patch to your overlay.

If the key is encrypted, also set `private_key_passphrase`.

### MySQL

A MySQL connection also accepts these fields:

- `database`: the database to connect to.
- `allow_insecure`: if `true`, Scout can connect without TLS. The default is `false`.
- `params`: other connection parameters, for example `charset` or `parseTime`.

## Environment variables

The Secret gets its values from two files:

- `base/agent.env` has a placeholder for each secret. `QUALITY_CLIENT_ID` and `QUALITY_CLIENT_SECRET` are empty.
- The overlay's `agent.env` sets the real values. Kustomize merges it with the base file key by key.

These variables are required:

| Variable | Description |
|---|---|
| `QUALITY_CLIENT_ID` | The client ID for the Coalesce Quality control plane. |
| `QUALITY_CLIENT_SECRET` | The client secret for the Coalesce Quality control plane. |
| `OPENAI_API_KEY` | The API key for LiteLLM or for the OpenAI-compatible API. |

Scout still reads the older names `SYNQ_CLIENT_ID` and `SYNQ_CLIENT_SECRET`. If you set both names, Scout uses the `QUALITY_` name. Thus you do not have to change an existing deployment.

These variables are optional:

| Variable | Default | Description |
|---|---|---|
| `VALIDATE_CONNECTIONS` | `true` | If `true`, Scout tests each connection when it starts. This prevents LLM costs on a connection that does not work. |
| `REQUIRE_VALID_CONNECTIONS` | `false` | If `true`, Scout does not start when a connection test fails. We recommend this in production. It works only when `VALIDATE_CONNECTIONS` is `true`. |
| `REQUIRE_CONTROL_PLANE` | `false` | If `true`, Scout does not start when it cannot get its configuration from the control plane. Scout tries 3 times, after 2s, 4s and 8s. If `false`, Scout logs a warning and uses only the local configuration. |
| `LOG_FORMAT` | `json` | `json` for log collection, or `text` for people to read. |
| `LOG_ADD_SOURCE` | `true` | If `true`, each log entry includes the source file and line. Set it to `false` to make the logs smaller. |
| `LOG_LEVEL` | `INFO` | The minimum level to log: `DEBUG`, `INFO`, `WARN` or `ERROR`. |

For example:

```bash
# Disable connection validation (not recommended)
VALIDATE_CONNECTIONS=false

# Enable strict validation (fail if any connection is misconfigured)
REQUIRE_VALID_CONNECTIONS=true

# Require control plane configuration (fail if cannot retrieve)
REQUIRE_CONTROL_PLANE=true

# For text logging (useful for debugging)
LOG_FORMAT=text

# Without source location (reduces log size and overhead)
LOG_ADD_SOURCE=false

# DEBUG level for troubleshooting
LOG_LEVEL=DEBUG
```

## Resources

`base/deployment.yaml` does not set resource requests or limits. To set them, add a deployment patch to your overlay.

## Automatic image updates

The deployment has annotations for [Keel](https://keel.sh/docs/). Keel checks the registry every minute and installs new minor and patch versions:

```yaml
annotations:
  keel.sh/policy: minor
  keel.sh/trigger: poll
  keel.sh/pollSchedule: "@every 1m"
```

To install Keel, run `kubectl apply -f keel.yaml`. The basic auth of Keel uses the user `admin` and the password `password`. Change them in `keel-values.yaml` and run `./keel.sh` to build `keel.yaml` again.

If you use GitOps, you can use [FluxCD image automation](https://fluxcd.io/flux/guides/image-update/) or [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/) instead. These tools write the new image version to your Git repository.

## Troubleshooting

1. Run `synq-scout health` in the pod. See [Verify the deployment](#verify-the-deployment).
2. Check the status of the pod:

   ```bash
   kubectl -n synq describe pod <pod-name>
   ```

3. Read the logs. For more detail, set `LOG_LEVEL=DEBUG` and restart the deployment.

   ```bash
   kubectl -n synq logs <pod-name>
   ```

4. Check the configuration that the pod uses:

   ```bash
   kubectl -n synq describe configmap
   ```

If the problem continues, contact Coalesce Quality support: https://docs.synq.io/support/support

## Remove the deployment

```bash
# With Kustomize
kubectl delete -k overlays/example

# OR with the generated file
kubectl delete -f synq-scout-example.yaml
```
