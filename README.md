# SYNQ Scout AI Kubernetes Deployment Guide

This guide provides step-by-step instructions for deploying the SYNQ Scout AI service on Kubernetes. You can choose between two deployment methods:

1. **Recommended**: Using Kustomize (for better environment management and configuration)
2. Direct deployment using kubectl

## Quick Start

If you're already familiar with Kubernetes and want to deploy quickly:

```bash
# Using Kustomize (Recommended)
kubectl apply -k overlays/example

# OR using direct deployment
kubectl apply -f synq-scout-example.yaml
```

## Prerequisites

Before you begin, ensure you have:

- ✅ Kubernetes cluster access configured
- ✅ `kubectl` CLI tool installed (v1.14+ with built-in kustomize support)
- ✅ Access to the container registry where the images are stored
- ✅ OpenAI-compatible API serving Claude 4 or 4.5 models (we recommend [LiteLLM](https://docs.litellm.ai/) v1.77.5-stable or later as a proxy)

## Project Structure

```
synq-scout-k8s/
├── base/                  # Base Kubernetes configurations
│   ├── deployment.yaml    # Main deployment configuration
│   ├── kustomization.yaml # Base kustomization file
│   ├── agent.yaml        # Agent configuration
│   └── agent.env         # Environment variables, store secrets here
└── overlays/             # Environment-specific overlays
    └── example/          # Example environment configuration
```

## API Requirements

SYNQ Scout requires access to an OpenAI-compatible API serving Claude 4 or Claude 4.5 models. We recommend using **LiteLLM v1.77.5-stable or later** as a proxy to handle this requirement.

### Setting up LiteLLM

LiteLLM provides a unified interface for various AI models and can serve Claude models through an OpenAI-compatible API. For Kubernetes deployments, LiteLLM should be deployed as a separate service.

#### Kubernetes Deployment (Recommended)

Follow the [LiteLLM Kubernetes deployment guide](https://docs.litellm.ai/docs/proxy/deploy#kubernetes) to deploy LiteLLM in your Kubernetes cluster. The basic deployment includes:

1. **ConfigMap** for LiteLLM configuration
2. **Secret** for API keys
3. **Deployment** with the LiteLLM container
4. **Service** to expose the proxy

Example configuration for Claude models:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-config-file
data:
  config.yaml: |
    model_list:
       - model_name: claude-4-5-sonnet
         litellm_params:
           model: claude-4-5-sonnet
           api_key: os.environ/ANTHROPIC_API_KEY
```

Claude models can be accessed through multiple providers via LiteLLM:
- **Direct Anthropic API**: Use `claude-4-5-sonnet` or `claude-4-sonnet` with `ANTHROPIC_API_KEY`
- **Google Vertex AI**: Use `vertex_ai/claude-4-5-sonnet` or `vertex_ai/claude-4-sonnet` with Google Cloud credentials
- **Amazon Bedrock**: Use `bedrock/claude-4-5-sonnet` or `bedrock/claude-4-sonnet` with AWS credentials

For provider-specific configuration, refer to the [LiteLLM provider documentation](https://docs.litellm.ai/docs/providers).

**Important**:
- SYNQ Scout has been tested with LiteLLM v1.77.5-stable
- Use versioned image tags (like v1.77.5-stable) instead of `main-stable` for production deployments

#### Configuration

After deploying LiteLLM, update your SYNQ Scout configuration to point to the LiteLLM service URL (e.g., `http://litellm-service:8000`) in your environment configuration files.

### Model Configuration

SYNQ Scout supports configurable AI models for different tasks:

- **Thinking Model**: Used for complex reasoning and analysis
- **Summary Model**: Used for generating summaries and reports

**Recommended Configuration**:
- **Claude 4.5 Sonnet** (`claude-4-5-sonnet`): Latest model, best quality for both thinking and summary tasks (still under review but no known issues)
- **Claude 4 Sonnet** (`claude-4-sonnet`): Stable production-ready model, excellent quality for both thinking and summary tasks
- `claude-3-5-haiku` can be used for summary generation (faster, cost-effective)

⚠️ **Note**: 
- Google AI Gemini models are work-in-progress and may work in some setups but are not recommended at this time
- OpenAI models are not supported

Models are configured in `base/agent.yaml` and can be customized per environment using Kustomize overlays. To override model settings for a specific environment, create a patch in your overlay directory (e.g., `overlays/example/agent.yaml`).

For more information, visit the [LiteLLM documentation](https://docs.litellm.ai/).

## Detailed Deployment Instructions

### 1. Using Kustomize (Recommended)

Kustomize provides better environment management and configuration customization:

1. **Review Base Configuration**

   - Navigate to `base/`
   - Review and modify configurations as needed
   - Pay special attention to resource limits and environment variables

2. **Environment Setup**

   - Choose an existing environment overlay from `overlays/`
   - Or create a new one by copying the `example` directory

3. **Deploy**

   ```bash
   kubectl apply -k overlays/example
   ```

### 2. Direct Deployment Using kubectl

For simpler deployments without environment-specific configurations:

```bash
kubectl apply -f synq-scout-example.yaml
```

⚠️ **Note**: When using direct deployment, you'll need to manually redeploy when configuration changes as checksums won't update automatically.

## Post-Deployment Verification

After deployment, verify everything is working correctly:

```bash
# Check deployment status
kubectl get deployments

# Check pods status
kubectl get pods

# View logs
kubectl logs -l app=synq-scout

# Test configuration and LLM connectivity
synq-scout health
```

The `synq-scout health` command validates that the configuration is correct and LLM connections are working as expected. This command will verify connectivity to the Scout AI control plane, test available data warehouse connections, and ensure both thinking and summary models are functioning properly.

## Configuration Guide

### Database Connection Configuration

SYNQ Scout connects to your data warehouses using connection configurations defined in `base/agent.yaml`. Each connection configuration includes:

- **Connection ID** (required): A string identifier that should match the integration ID from SYNQ platform
  - UUIDs are strongly recommended as they improve deterministic behavior
  - Other string identifiers can be used but may affect agent behavior consistency
- **name** (optional): Human-readable name for the connection
  - Defaults to the connection ID if not specified
- **disabled** (optional): Boolean flag to enable/disable the connection
  - Defaults to `false` (enabled) if not specified
- **parallelism** (optional): Number of parallel queries
  - Defaults to `8` if not specified
  - Adjust based on warehouse size and capabilities (see guidance below)
- **Database credentials** (required): Specific configuration for your database type

**Connection ID Matching**: Connection IDs should match the IDs from your SYNQ platform integrations. This ensures the Agent can correctly map connections to SYNQ platform data and maintain consistent tracking.

**Recommended Setup Method**:

**Auto-generate from SYNQ UI** (Strongly Recommended): Visit https://app.synq.io/settings/scout to automatically generate connection configurations. This ensures:
- Connection IDs match SYNQ platform integration IDs
- UUIDs are used for deterministic agent behavior
- All required fields are included with correct structure
- Consistent configuration across environments

**Manual Configuration** (Not Recommended): If you must configure manually, you need to:
1. Obtain the correct ID from your SYNQ platform integration (preferably UUID)
2. Configure database-specific credentials
3. Optionally customize `name`, `disabled`, or `parallelism` (if defaults don't suit your needs)
4. Use environment variable references for credentials (e.g., `${POSTGRES_PASSWORD}`)
5. Define corresponding environment variables in `base/agent.env` or your overlay's `.env` file

**Parallelism Configuration**:

The `parallelism` setting controls how many queries can run concurrently per connection. The default value is **8**, which works well for most medium to large warehouses. Adjust based on your warehouse:

- **Small warehouses / Development**: `parallelism: 1-2` (reduce from default to avoid overwhelming small systems)
- **Medium warehouses**: `parallelism: 4-8` (default of 8 is appropriate)
- **Large warehouses**: `parallelism: 8-16` (default is good, or increase for better throughput)
- **Serverless/Autoscaling warehouses**: `parallelism: 16+` (increase to fully leverage automatic scaling capabilities)

**Supported Database Types**:
- PostgreSQL
- MySQL
- BigQuery
- ClickHouse
- Snowflake

For detailed configuration schema and additional options, see the [official documentation](https://docs.synq.io/dw-integrations/agent#config-file-schema).

### Environment Variables

Environment variables are managed in two places:

- Base configuration: `base/agent.env`
- Environment-specific variables: Located in respective overlay directories

### Resource Configuration

Resource limits and requests can be adjusted in:

- Base deployment: `base/deployment.yaml`
- Environment-specific: In respective overlay's patch files

### Container Image Auto-Updates

We recommend using an auto-update tool to keep your SYNQ Scout deployment current with the latest container versions. The agent deployment includes annotations to work with [Keel.sh](https://keel.sh/docs/) by default:

```yaml
annotations:
  keel.sh/policy: minor
  keel.sh/trigger: poll
  keel.sh/pollSchedule: "@every 5m"
```

#### Keel.sh (Recommended)
- **Simple setup**: Deploy as a single Kubernetes deployment
- **Annotation-based**: Configure updates directly in deployment manifests
- **Flexible policies**: Support for major, minor, patch, and force update policies
- **Multiple triggers**: Poll, webhook, and approval-based updates

#### Alternative Auto-Update Tools

**GitOps-Based Solutions:**
- **FluxCD with Image Automation**: Automatically updates Git repositories when new images are available, following GitOps principles
- **ArgoCD Image Updater**: Updates ArgoCD applications with new container images while maintaining Git-based configuration

Choose based on your workflow: GitOps-based solutions (FluxCD/ArgoCD) for production environments with full Git-based configuration management.

## Troubleshooting Guide

If you encounter issues, follow these steps:

1. **Check Pod Status**

   ```bash
   kubectl describe pod <pod-name>
   ```

2. **View Logs**

   ```bash
   kubectl logs <pod-name>
   ```

3. **Verify Configurations**
   ```bash
   kubectl get configmap
   kubectl describe configmap
   ```

## Cleanup Instructions

To remove the deployment:

```bash
# Using Kustomize
kubectl delete -k overlays/example

# OR direct deployment
kubectl delete -f synq-scout-example.yaml
```

## Need Help?

If you encounter any issues or need help:

1. Check the troubleshooting section above
2. Review the logs using `kubectl logs`
3. Contact the SYNQ team for support
