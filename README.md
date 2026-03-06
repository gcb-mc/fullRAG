# ATLAS-RAG SharePoint Agent

An enterprise Retrieval-Augmented Generation (RAG) agent that enables natural-language question-and-answer over SharePoint content. Built on **Azure AI Foundry Agent Service** with GPT-4o, it uses Microsoft Entra ID On-Behalf-Of (OBO) flow to retrieve SharePoint data within the scope of the signed-in user's permissions.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Azure Container Apps                 │
│                  (FastAPI · Python 3.11)                 │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTPS
          ┌─────────────▼─────────────┐
          │  Azure AI Foundry         │
          │  Agent Service            │
          │  · GPT-4o                 │
          │  · SharePoint tool        │
          │  · File Search            │
          └──┬────────────┬───────────┘
             │            │
   ┌──────────▼──┐  ┌──────▼──────────┐
   │ Azure AI    │  │  Azure Cosmos DB │
   │ Search      │  │  (thread store)  │
   │ (hybrid +   │  └─────────────────┘
   │  semantic)  │
   └─────────────┘
```

| Layer | Technology |
|---|---|
| **Backend API** | FastAPI on Azure Container Apps |
| **AI Agent** | Azure AI Foundry Agent Service (GPT-4o + SharePoint tool + File Search) |
| **Search** | Azure AI Search — hybrid + semantic re-ranking |
| **Conversation Storage** | Azure Cosmos DB (NoSQL — `threads` & `conversations` containers) |
| **File Storage** | Azure Blob Storage (`agent-files` container) |
| **Authentication** | Microsoft Entra ID — On-Behalf-Of (OBO) flow for user-scoped SharePoint access |
| **Identity (service-to-service)** | User-Assigned Managed Identity — no connection strings in code |
| **Secrets** | Azure Key Vault |
| **Observability** | Azure Application Insights + Log Analytics |
| **Infrastructure as Code** | Azure Developer CLI (AZD) + Bicep |

---

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (latest recommended)
- [Azure Developer CLI (AZD)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd) (latest recommended)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (installed via `az bicep install`)
- An Azure subscription with Contributor + User Access Administrator roles
- A Microsoft Entra ID app registration with SharePoint delegated permissions (`Sites.Read.All` or broader)
- Python 3.11+ (for local development)
- Docker (for local container builds)

---

## Quick Start — Deploy to Azure

```bash
# 1. Log in to Azure
azd auth login

# 2. Create a dev environment (resource group: rg-rag-test-dev)
azd env new rag-test-dev

# 3. Provision all Azure resources (~15-20 min the first time)
azd provision

# 4. Build and deploy the container
azd deploy
```

For a production environment:

```bash
azd env new rag-test-prod
azd provision   # isProd=true activates Standard tiers, private endpoints, and HA replicas
azd deploy
```

---

## Environment Naming

| Environment | AZD env name | Resource Group |
|---|---|---|
| Development | `rag-test-dev` | `rg-rag-test-dev` |
| Production | `rag-test-prod` | `rg-rag-test-prod` |

The `isProd` flag is derived automatically from whether the environment name contains `prod`. It controls SKU tiers, replica counts, retention periods, and whether private networking is enabled.

---

## Repository Structure

```
fullRAG/
├── azure.yaml                      # AZD service definitions (api → Container Apps)
├── .env.example                    # Environment variable template for local dev
├── AGENTS.md                       # Copilot coding agent instructions
├── infra/
│   ├── main.bicep                  # Subscription-scoped entry point; creates resource group & deploys all modules
│   ├── main.parameters.json        # AZD-injected parameter values
│   ├── abbreviations.json          # Azure resource abbreviation map
│   └── modules/
│       ├── monitoring.bicep        # Log Analytics + Application Insights
│       ├── managed-identity.bicep  # User-Assigned Managed Identity
│       ├── key-vault.bicep         # Key Vault (RBAC-mode, soft delete)
│       ├── container-registry.bicep# Azure Container Registry
│       ├── ai-services.bicep       # Azure AI Services (GPT-4o + embeddings)
│       ├── ai-foundry.bicep        # AI Hub + AI Project + Capability Host
│       ├── ai-search.bicep         # Azure AI Search (hybrid + semantic)
│       ├── cosmos-db.bicep         # Cosmos DB — threads & conversations
│       ├── storage-account.bicep   # Blob Storage for agent files
│       ├── container-apps.bicep    # Container Apps Environment + app
│       └── security.bicep          # All RBAC role assignments (centralized)
└── src/
    └── api/
        └── Dockerfile              # Python 3.11 slim, uvicorn on port 8000
```

---

## Local Development

1. **Copy and configure the environment file:**

   ```bash
   cp .env.example .env
   # Fill in all values — see .env.example for descriptions
   ```

2. **Install Python dependencies:**

   ```bash
   cd src/api
   pip install -r requirements.txt
   ```

3. **Run the API locally:**

   ```bash
   uvicorn main:app --reload --port 8000
   ```

   The API will be available at `http://localhost:8000`.

4. **Build the container image locally:**

   ```bash
   docker build -t atlas-rag-api ./src/api
   docker run -p 8000:8000 --env-file .env atlas-rag-api
   ```

> **Note:** Load your `.env` file into environment variables before starting the app (e.g., `export $(grep -v '^#' .env | xargs)`). `DefaultAzureCredential` then picks up credentials via its standard chain: environment variables (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`), followed by `az login`. In production the Container App authenticates using `ManagedIdentityCredential` via `AZURE_CLIENT_ID`.

---

## Environment Variables

| Variable | Description |
|---|---|
| `ENVIRONMENT` | `development` or `production` |
| `AZURE_CLIENT_ID` | Client ID of the User-Assigned Managed Identity |
| `AZURE_AI_PROJECT_ENDPOINT` | AI Foundry project endpoint URL |
| `AZURE_AI_SERVICES_ENDPOINT` | Azure AI Services (OpenAI) endpoint URL |
| `AZURE_COSMOS_ENDPOINT` | Cosmos DB account endpoint URL |
| `AZURE_SEARCH_ENDPOINT` | Azure AI Search service endpoint URL |
| `AZURE_KEY_VAULT_URL` | Key Vault URI |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights connection string |
| `AZURE_TENANT_ID` | Entra ID tenant ID (for OBO flow) |
| `AZURE_CLIENT_SECRET` | App registration client secret (OBO — local dev only) |
| `ENTRA_APP_CLIENT_ID` | Entra ID app registration client ID |
| `SHAREPOINT_SITE_URL` | SharePoint site URL to query |

All secrets (`AZURE_CLIENT_SECRET`, `APPLICATIONINSIGHTS_CONNECTION_STRING`, etc.) are stored in **Azure Key Vault**. In production, the Container App injects them at runtime via Key Vault references using the Managed Identity — they are never hard-coded or stored as plain-text environment variables in production deployments.

---

## Infrastructure Overview

All Azure resources are provisioned via Bicep modules orchestrated by `infra/main.bicep`:

| Phase | Resources |
|---|---|
| **Shared Services** | Log Analytics, Application Insights, User-Assigned Managed Identity, Key Vault, Container Registry |
| **AI & Data** | Azure AI Services (GPT-4o + embeddings), AI Foundry Hub + Project, Azure AI Search, Cosmos DB, Blob Storage |
| **Compute** | Container Apps Environment + Container App (FastAPI) |
| **Security** | RBAC role assignments (all in `security.bicep`) |
| **Networking (prod)** | Private endpoints for all services, VNet, private DNS zones |

### Key Design Decisions

- **User-Assigned Managed Identity** — one identity for the Container App to authenticate to all backends; RBAC is pre-assigned before deployment.
- **RBAC centralized in `security.bicep`** — all role assignments in one place for auditability.
- **Cosmos DB serverless** (dev) / **autoscale** (prod) — cost-optimized for dev, predictable throughput for prod.
- **AI Search free tier** (dev) / **Standard** (prod) — sufficient for development, standard for hybrid + semantic ranking at scale.
- **Private endpoints** in prod only — balances security for regulated environments with development agility.

---

## Validate the Infrastructure (without deploying)

```bash
# Lint all Bicep files
az bicep build --file infra/main.bicep

# Preview changes (what-if)
az deployment sub what-if \
  --location eastus2 \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

---

## Contributing

1. Fork the repository and create a feature branch.
2. Follow the conventions in [AGENTS.md](./AGENTS.md) — no connection strings in code, use Managed Identity, store secrets in Key Vault.
3. Validate Bicep changes with `az bicep build` before opening a pull request.
4. Open a pull request targeting `main`.

---

## License

This project is licensed under the [MIT License](LICENSE).
