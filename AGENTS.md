# ATLAS-RAG SharePoint Agent — Coding Instructions

## Project Overview
Enterprise RAG agent using Azure AI Foundry Agent Service with SharePoint tool for natural-language Q&A over SharePoint content. Uses Entra ID OBO for user-scoped retrieval.

## Architecture
- **Backend**: FastAPI on Azure Container Apps
- **Agent**: Azure AI Foundry Agent Service (GPT-4o + SharePoint tool + File Search)
- **Search**: Azure AI Search (hybrid + semantic re-ranking)
- **Storage**: Cosmos DB (conversation threads), Azure Storage (agent files)
- **Auth**: Microsoft Entra ID with On-Behalf-Of (OBO) flow
- **IaC**: AZD + Bicep (`infra/` directory)

## Key Conventions
- All service-to-service auth uses **User-Assigned Managed Identity** — no connection strings in code
- Use `ManagedIdentityCredential` in production, `DefaultAzureCredential` only in local dev
- Secrets go in **Azure Key Vault**, never in code or environment variables
- RBAC assignments are centralized in `infra/modules/security.bicep`
- Bicep modules use `isProd` parameter to toggle SKU tiers and networking
- Container App env vars inject service endpoints (not secrets)

## File Structure
```
infra/main.bicep            → Subscription-scoped entry point
infra/modules/*.bicep       → One module per Azure service
azure.yaml                  → AZD service definitions
src/api/                    → FastAPI application
src/api/Dockerfile          → Container image definition
```

## Deployment
```bash
azd auth login
azd env new rag-test-dev
azd provision    # Creates all Azure resources
azd deploy       # Builds and deploys the container
```

## Environment Prefix
- Dev: `rag-test-dev` → Resource group `rg-rag-test-dev`
- Prod: `rag-test-prod` → Resource group `rg-rag-test-prod`
