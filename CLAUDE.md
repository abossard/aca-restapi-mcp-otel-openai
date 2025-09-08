# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is an AI-enhanced REST API solution built with Azure services. The architecture consists of:

- **FastAPI Application** (`src/aiapi/server.py`): Main REST API server with OpenTelemetry instrumentation
- **Azure Infrastructure** (`infra/main.tf`): Terraform configuration for Azure Container Apps, OpenAI, AI Search, and monitoring
- **AI Integration**: Azure OpenAI (GPT-4o) and Azure AI Search with 10k HTML document embeddings
- **Observability**: OpenTelemetry + Application Insights + DataDog integration
- **Security**: Managed Identity authentication, private endpoints, VPN to Netherlands

## Key Components

### API Layer
- FastAPI-based REST service with Swagger/OpenAPI documentation
- OpenTelemetry instrumentation for distributed tracing
- Managed Identity for secure Azure service access

### AI Services Integration
- **Azure OpenAI**: GPT-4o models for natural language processing
- **Azure AI Search**: Vector search with 1GB index capacity
- **Azure AI Foundry**: Model deployment and management platform

### Infrastructure
- **Azure Container Apps**: Auto-scaling hosting (0-1 instances)
- **Private Endpoints**: Secure connectivity within Azure
- **VPN Connection**: Secure access to Netherlands-based resources
- **Cost Optimization**: Idle scaling for 2% savings, designed for 10-20 users

## Development Commands

The project is currently in early stages with minimal files. Based on the architecture:

### Local Development
```bash
# Set up Python environment
cd src/aiapi
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Run FastAPI server locally
python src/aiapi/server.py
# or
uvicorn src.aiapi.server:app --reload
```

### Infrastructure Management
```bash
# Navigate to infrastructure directory
cd infra

# Initialize and plan Terraform
terraform init
terraform plan -out=tfplan

# Apply infrastructure changes
terraform apply tfplan
```

### Container Operations
```bash
# Build container image
docker build -t <registry>/api:latest .

# Deploy to Azure Container Apps
az containerapp update --name <app-name> --resource-group <rg-name> --image <registry>/api:latest
```

## Environment Configuration

Create `.env` file with Azure service endpoints:
- Azure OpenAI endpoint and API keys
- Azure AI Search service configuration
- Application Insights connection string
- Managed Identity client ID

## Deployment Strategy

- **Frequency**: 1-2 deployments per year
- **Scaling**: 0-1 instances with auto-scaling
- **Environments**: Development, Staging, Production with different SKUs
- **Blue-Green**: Recommended deployment strategy for production

## Important Notes

- All Azure services use Managed Identity for authentication
- OpenTelemetry is integrated for comprehensive observability
- Private endpoints ensure secure service-to-service communication
- Cost optimized for small user base (10-20 users) with idle scaling
- Infrastructure uses Terraform with configurable variables for different environments
- Terraform should never use depends-on for resource dependencies but use implicit ones
- follow Grokking Simplicity principles for any Python code
- follow A Philosophy of Software Design principles for any Python code
- keep the README.md a source of truth on what TODOs are remaining and update them there.
- for each special Azure resource, e.g. AI Search:
  1. Search online how to create it in Terraform
  2. Add a generic example into a new markdown file in /docs and link it to the todo in the README.md
  3. Only then start installing it

- test the terraform with creating a Plan