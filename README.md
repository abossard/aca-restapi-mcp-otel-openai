# AI-Enhanced REST API with Model Context Protocol, OpenTelemetry, and Azure Services

## Overview
This project implements an AI-enhanced REST API solution, OpenTelemetry monitoring, and Azure services. The architecture provides a scalable, observable, and intelligent system for handling REST API requests with AI capabilities.

## Architecture

The solution consists of several key components:

### Core Components
- **REST API**: FastAPI-based REST service with OpenAPI/Swagger documentation
- **Azure Container App**: Hosts the REST API with auto-scaling capabilities
- **OpenTelemetry Agent**: Provides comprehensive observability and monitoring

### AI Services
- **Azure AI Foundry Hub**: Central workspace for AI model management and deployment
- **Azure AI Foundry Project**: Project-specific environment within the hub
- **Azure AI Services**: Multi-service cognitive account hosting GPT-4o and GPT-4o-mini models
- **Azure AI Search**: Vector search with 1GB index for 10k HTML documents as embeddings

### Infrastructure & Security
- **Azure Management API**: Infrastructure management and orchestration
- **Managed Identity**: Secure authentication without credentials
- **Private Endpoints**: Secure network connectivity within Azure
- **VPN to Netherlands**: Secure connection to on-premises resources

### Monitoring & Observability
- **Application Insights**: Application performance monitoring and analytics
- **OpenTelemetry**: Distributed tracing and metrics collection
- **DataDog**: External monitoring and alerting platform

### Telemetry Modes
This project supports two mutually exclusive telemetry initialization paths:

1. Azure Monitor OpenTelemetry Distro (preferred when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set)
  - Activated automatically when the env var `APPLICATIONINSIGHTS_CONNECTION_STRING` is present.
  - Uses `azure-monitor-opentelemetry` to configure exporters (traces/logs/metrics as supported) and default instrumentation (FastAPI, requests, etc.).
  - Resource attributes can be extended via `OTEL_RESOURCE_ATTRIBUTES` and `OTEL_SERVICE_NAME`.
  - Disable a built-in instrumentation via `OTEL_PYTHON_DISABLED_INSTRUMENTATIONS` (comma-separated names, e.g. `fastapi,requests`).

2. Manual OTLP exporter fallback (no App Insights connection string)
  - Endpoint resolution precedence:
    1. `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`
    2. `OTEL_EXPORTER_OTLP_ENDPOINT`
    3. `CONTAINERAPP_OTEL_TRACING_GRPC_ENDPOINT` (injected by Azure Container Apps managed OpenTelemetry agent)
    4. Default: `http://localhost:4317`
  - Protocol expected: gRPC (`OTEL_EXPORTER_OTLP_PROTOCOL=grpc`). Non‑gRPC values log a warning.
  - FastAPI + requests are explicitly instrumented in code.

Avoid Double Instrumentation:
- Do not manually add extra exporters when the Azure Monitor distro path is active.
- To force OTLP-only mode, omit `APPLICATIONINSIGHTS_CONNECTION_STRING` from the container environment.

Environment Variables Summary:
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: Activates Azure Monitor distro.
- `OTEL_SERVICE_NAME`, `OTEL_SERVICE_VERSION`: Override service identity (else defaults applied in code/Terraform).
- `OTEL_RESOURCE_ATTRIBUTES`: Additional resource attributes (e.g. `deployment.environment=dev`).
- `OTEL_EXPORTER_OTLP_(TRACES_)ENDPOINT`: Custom OTLP targets in fallback mode.
- `OTEL_PYTHON_DISABLED_INSTRUMENTATIONS`: Comma list to disable instrumentations in distro mode.

Terraform Injection:
- Terraform sets `APPLICATIONINSIGHTS_CONNECTION_STRING` on the Container App; unset it to test pure OTLP path locally.

Local Dev Tips:
```bash
# Run with App Insights disabled (manual OTLP -> local collector)
unset APPLICATIONINSIGHTS_CONNECTION_STRING
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
uvicorn src.aiapi.server:app --reload

# Run with Azure Monitor distro
export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=...;IngestionEndpoint=..."
uvicorn src.aiapi.server:app --reload
```


### Pricing & Scale
- **Scale**: 0-1 instances with idle pricing
- **User Base**: Designed for 10-20 potential users
- **Data updates**: 1-2 deployments per year pipeline

## Use Cases

1. **AI-Enhanced API Responses**: Leverage GPT-4o models to provide intelligent responses
2. **Document Search**: Search through 10k HTML documents using AI Search embeddings
3. **Observability**: Comprehensive monitoring and tracing of API requests
4. **Secure AI Integration**: Use managed identities for secure service-to-service communication
5. **Scalable Architecture**: Auto-scaling based on demand with cost optimization

## Technology Stack

- **Language**: Python
- **API Framework**: FastAPI
- **AI Platform**: Azure OpenAI (GPT-4o)
- **Search**: Azure AI Search
- **Hosting**: Azure Container Apps
- **Monitoring**: OpenTelemetry + Application Insights + DataDog
- **Authentication**: Azure Managed Identity
- **Infrastructure**: Terraform with Azure Provider
- **Containerization**: Docker

## Prerequisites

Before setting up this project, ensure you have:

- Azure subscription with appropriate permissions
- Azure CLI installed and configured
- Terraform >= 1.5.0 installed
- Docker for local development
- Python 3.9+ for local development
- Access to Azure OpenAI services
- Network connectivity to Netherlands (if VPN is required)

## Terraform Configuration Variables

The infrastructure is designed to be highly configurable through Terraform variables. Below are the key parameters that can be customized:

### Core Infrastructure Variables
- **Location**: Azure region for resource deployment (default: Switzerland North)
- **Resource Group Name**: Name of the resource group
- **Project Name**: Project name used for resource naming
- **Environment**: Environment name (dev, staging, prod)
- **Tags**: Resource tags for organization and cost tracking

### AI Services Configuration
- **OpenAI Models**: List of models to deploy with versions and capacity
- **OpenAI SKU**: Service tier for Azure OpenAI (S0, S1, etc.)
- **AI Search SKU**: Service tier for Azure AI Search (basic, standard, premium)
- **AI Search Replicas**: Number of replicas for high availability
- **AI Search Partitions**: Number of partitions for scaling
- **Document Index Size**: Size of document index in GB
- **Document Count**: Expected number of documents to index

### Security and Access Control
- **API Exposure**: Type of API exposure (public, internal, private)
- **Create Entra App Registration**: Whether to create app registration in Terraform
- **Entra App Registration ID**: Existing app registration ID if not creating new
- **Entra Tenant ID**: Azure AD tenant identifier
- **Enable Private Endpoints**: Enable private endpoints for Azure services
- **Allowed IP Ranges**: IP ranges allowed to access public endpoints

### Networking Configuration
- **VNet Address Space**: Virtual network address space
- **Subnet Configurations**: Subnet layouts and service endpoints

### Container Apps Scaling
- **Min/Max Replicas**: Scaling boundaries (0-1 instances)
- **Container Resources**: CPU and memory allocation per container
- **Idle Timeout**: Timeout for scaling to zero (cost optimization)

### Monitoring and Observability
- **Application Insights Type**: Type of Application Insights (web, other)
- **Log Analytics Retention**: Log retention period in days
- **Custom Metrics Enabled**: Enable custom metrics collection

### Performance and Cost Optimization
- **Enable Cost Optimization**: Enable cost optimization features
- **Rate Limiting**: API rate limiting configuration

## Implementation Progress

For detailed task tracking and implementation status, see [TODOS.md](TODOS.md).

**Key Achievements:**
- ✅ Complete Azure AI Foundry + GPT-4o infrastructure
- ✅ Container Apps with Managed Identity authentication  
- ✅ Private endpoints and secure networking
- ✅ Auto-scaling and cost optimization features
- ✅ OpenTelemetry monitoring integration

**Next Steps:**
- 🔄 Container image deployment to ACR
- 🔄 Document indexing in AI Search
- 🔄 Production monitoring and alerting

## Pre-Deployment Preparation Checklist

Before deploying the infrastructure, ensure you have completed the following preparation steps:

### 1. Azure Prerequisites
- [ ] **Azure CLI installed and authenticated**: `az login`
- [ ] **Appropriate Azure subscription permissions**: 
  - Contributor or Owner role on the target subscription
  - Permission to create service principals and assign roles
  - Access to create resources in the target region (Switzerland North by default)
- [ ] **Resource Provider Registration**: Ensure the following providers are registered:
  ```bash
  az provider register --namespace Microsoft.CognitiveServices
  az provider register --namespace Microsoft.MachineLearningServices  
  az provider register --namespace Microsoft.Search
  az provider register --namespace Microsoft.App
  az provider register --namespace Microsoft.ContainerRegistry
  az provider register --namespace Microsoft.KeyVault
  ```

### 2. Terraform Setup
- [ ] **Terraform >= 1.5.0 installed**: Verify with `terraform --version`
- [ ] **Configure Terraform backend** (recommended for production):
  ```bash
  # Create storage account for Terraform state
  az storage account create --name tfstateXXXXX --resource-group rg-terraform-state --location switzerlandnorth
  ```
- [ ] **Review and customize terraform.tfvars**: Copy from terraform.tfvars.example and adjust:
  - Project naming conventions
  - Environment settings (dev/staging/prod)
  - Regional deployment preferences
  - Private endpoint requirements
  - AI model configurations

### 3. Network Planning (if using Private Endpoints)
- [ ] **Plan VNet address spaces**: Ensure no conflicts with existing networks
- [ ] **DNS resolution strategy**: Plan for private DNS zones
- [ ] **Connectivity requirements**: VPN or ExpressRoute to Netherlands if needed
- [ ] **Network security**: Plan NSG rules and firewall configurations

### 4. Application Preparation
- [ ] **Container image built and tested locally**:
  ```bash
  docker build -t aca-restapi-mcp:latest .
  docker run -p 8000:8000 aca-restapi-mcp:latest
  ```
- [ ] **Environment variables configured**: All required variables for Managed Identity auth
- [ ] **Application Insights integration tested**: OpenTelemetry configuration verified

### 5. Security Configuration
- [ ] **Key Vault access policies planned**: Determine what secrets/keys are needed
- [ ] **Managed Identity permissions reviewed**: RBAC roles for AI services access
- [ ] **Private endpoint requirements finalized**: Public vs private access decision

### 6. Monitoring & Alerting Setup
- [ ] **Application Insights workspace configured**: Log retention and sampling rates
- [ ] **Custom metrics identified**: Application-specific monitoring requirements
- [ ] **Alert rules planned**: Performance, error rate, and cost monitoring

### 7. Deployment Planning
- [x] **Deployment sequence documented**: Terraform manages resource dependencies automatically
- [x] **Rollback strategy prepared**: Terraform state management and resource recreation
- [x] **Testing strategy**: Post-deployment validation via API endpoints and health checks
- [x] **Documentation updated**: README and operational docs are current

## Current Deployment Status

The infrastructure is **deployment-ready** with the following components configured:

### 🟢 Ready to Deploy (via Terraform)
- **Azure AI Foundry Hub + Project**: Complete workspace for AI model management
- **Azure AI Services**: GPT-4o and GPT-4o-mini model deployments  
- **Azure AI Search**: 1GB vector search service for document embeddings
- **Container Apps**: Auto-scaling FastAPI application (0-1 instances)
- **Monitoring Stack**: Application Insights + OpenTelemetry integration
- **Security**: User-Assigned Managed Identity with proper RBAC
- **Networking**: Optional private endpoints with DNS resolution

### 🟡 Manual Configuration Required
- **Container Image**: Build and push application image to ACR
- **Document Indexing**: Upload and index 10k HTML documents in AI Search
- **CI/CD Pipeline**: GitHub Actions or Azure DevOps automation
- **Custom Alerts**: Performance and error monitoring rules

### ⚡ Ready for Production
- **Zero-Cost Idle**: Scale to 0 instances when not in use
- **Secure by Default**: Managed Identity authentication, no API keys
- **Enterprise Ready**: Private endpoints, audit logging, RBAC permissions
- **Fully Observable**: Distributed tracing, metrics, and structured logging

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd aca-restapi-mcp-otel-openai
   ```

2. **Set up local development environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
  pip install -r requirements.txt  # intentionally unpinned to fetch latest versions
  # (Optional) lock the resolved versions for deterministic builds
  pip freeze > requirements.lock
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your Azure service endpoints and keys
   ```

4. **Deploy Azure infrastructure**
   ```bash
   # Initialize Terraform
   cd infra
   terraform init
   
   # Create terraform.tfvars with your configuration
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   
   # Plan the deployment (public access - default)
   terraform plan -out=tfplan
   
   # OR: Plan with private endpoints enabled
   terraform plan -var="enable_private_endpoints=true" -out=tfplan
   
   # Apply the infrastructure
   terraform apply tfplan
   ```

5. **Build and deploy the application**
   ```bash
   # Build and push container image
   docker build -t <registry>/api:latest .
   docker push <registry>/api:latest
   
   # Deploy to Container Apps
   az containerapp update --name <app-name> --resource-group <rg-name> --image <registry>/api:latest
   ```

## Cost Optimization

- **Auto-scaling**: Scale to 0 instances during idle periods (2% cost savings)
- **Reserved Instances**: Consider reserved capacity for consistent workloads
- **Resource Right-sizing**: Monitor and adjust resource allocation based on usage
- **Lifecycle Management**: Implement data retention policies for logs and metrics

## Private Endpoints Configuration

Private endpoints provide secure connectivity to Azure services within your VNet, eliminating exposure to the public internet.

### Enable Private Endpoints

Set the `enable_private_endpoints` variable to `true`:

```bash
# Via command line
terraform plan -var="enable_private_endpoints=true"

# Via terraform.tfvars file
enable_private_endpoints = true
vnet_address_space = ["10.0.0.0/16"]  # Optional: customize network
private_endpoint_subnet_address_prefixes = ["10.0.1.0/24"]
```

### What Gets Created

When private endpoints are enabled, the following additional resources are created:

**Networking**:
- Virtual Network with configurable address space
- Dedicated subnet for private endpoints
- Private DNS zones for each service:
  - `privatelink.openai.azure.com`
  - `privatelink.search.windows.net`
  - `privatelink.azurecr.io`

**Security**:
- Public network access disabled for all Azure services
- Private endpoints for OpenAI, AI Search, and Container Registry
- Automatic DNS resolution to private IP addresses

### Resource Count Impact

- **Public Access (Default)**: 13 resources
- **Private Endpoints Enabled**: 24 resources (+11 networking resources)

## Infrastructure Configuration Best Practices

### Environment-Specific Configurations

- **Development**: Use minimal SKUs, enable debugging features, shorter retention periods
- **Staging**: Mirror production configuration with reduced scale
- **Production**: High availability, enhanced security, longer retention, monitoring alerts

### Security Considerations

- **API Exposure**: 
  - `public`: Internet-accessible with authentication
  - `internal`: Corporate network access only
  - `private`: VNet-only access with private endpoints
- **Entra ID Integration**: Create app registrations in Terraform for full infrastructure-as-code
- **Network Security**: Use private endpoints for all Azure PaaS services in production

### Cost Management

- Configure appropriate idle timeouts based on usage patterns
- Use spot instances for non-critical workloads
- Implement lifecycle policies for storage and logs
- Monitor and optimize AI model token usage

### Monitoring Strategy

- **Development**: Basic monitoring with longer sampling rates
- **Production**: Comprehensive monitoring with alerting and external integrations
- **DataDog Integration**: Enable for enterprise monitoring requirements

## Support and Maintenance

- **Monitoring**: 24/7 monitoring through Application Insights and DataDog
- **Updates**: Scheduled maintenance windows for updates and patches
- **Backup**: Automated backup of configuration and data
- **Documentation**: Keep operational runbooks up to date
- **Dependency Management**: `requirements.txt` is unpinned by design; generate `requirements.lock` via `pip freeze` (or use pip-tools) to pin for production. Keep OpenTelemetry package versions aligned.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and add tests
4. Submit a pull request

## License

[Insert appropriate license information]

---

**Note**: This project is designed for 10-20 users with 1-2 deployments per year. The architecture emphasizes cost optimization, security, and observability while providing advanced AI capabilities through Azure services.