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
- ✅ OpenAI-compatible API serving `claude-3-5-sonnet` model (we recommend [LiteLLM](https://docs.litellm.ai/) as a proxy)

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

SYNQ Scout requires access to an OpenAI-compatible API serving the `claude-3-5-sonnet` model. We recommend using **LiteLLM** as a proxy to handle this requirement.

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
       - model_name: claude-3-5-sonnet
         litellm_params:
           model: claude-3-5-sonnet
           api_key: os.environ/ANTHROPIC_API_KEY
```

Claude models can be accessed through multiple providers via LiteLLM:
- **Direct Anthropic API**: Use `claude-3-5-sonnet` with `ANTHROPIC_API_KEY`
- **Google Vertex AI**: Use `vertex_ai/claude-3-5-sonnet` with Google Cloud credentials
- **Amazon Bedrock**: Use `bedrock/claude-3-5-sonnet` with AWS credentials

For provider-specific configuration, refer to the [LiteLLM provider documentation](https://docs.litellm.ai/docs/providers).

**Important**: Use versioned image tags instead of `main-stable` for production deployments.

#### Configuration

After deploying LiteLLM, update your SYNQ Scout configuration to point to the LiteLLM service URL (e.g., `http://litellm-service:8000`) in your environment configuration files.

### Model Configuration

SYNQ Scout supports configurable AI models for different tasks:

- **Thinking Model**: Used for complex reasoning and analysis
- **Summary Model**: Used for generating summaries and reports

**Recommended Configuration**:
- `claude-4-5-sonnet` for both thinking and summary (best quality)
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
