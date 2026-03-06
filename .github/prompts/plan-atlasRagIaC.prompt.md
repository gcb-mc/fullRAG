# ATLAS-RAG Bicep IaC Plan (AZD + Bicep)

## Configuration

| Parameter | Value |
|---|---|
| **Subscription** | `f6eb08ce-f112-4889-9891-829161ecbd66` |
| **Location** | `eastus2` |
| **Environment prefix** | `macu-atlas` (→ `rg-macu-atlas-dev`, `rg-macu-atlas-prod`) |
| **IaC Recipe** | AZD + Bicep |
| **Environments** | Dev + Prod |
| **Networking** | Public (dev) / Private endpoints (prod) |
| **AI Foundry** | Create from scratch |

---

## Phase 0 — Project Scaffolding

1. Create the directory structure rooted at the workspace:

   ```
   atlas-rag-sharepoint-agent/
   ├── .azure/
   │   └── plan.md
   ├── azure.yaml
   ├── infra/
   │   ├── main.bicep
   │   ├── main.parameters.json
   │   ├── abbreviations.json
   │   └── modules/
   │       ├── monitoring.bicep
   │       ├── managed-identity.bicep
   │       ├── key-vault.bicep
   │       ├── container-registry.bicep
   │       ├── ai-services.bicep
   │       ├── ai-foundry.bicep
   │       ├── ai-search.bicep
   │       ├── cosmos-db.bicep
   │       ├── storage-account.bicep
   │       ├── container-apps.bicep
   │       └── security.bicep        (all RBAC role assignments)
   ├── src/
   │   └── api/
   │       └── Dockerfile
   ├── .env.example
   └── AGENTS.md
   ```

2. Create `azure.yaml` with a single `api` service targeting Container Apps:
   - `name: atlas-rag`
   - Service `api`: `project: ./src/api`, `host: containerapp`, `language: python`

---

## Phase 1 — Core Platform (infra/main.bicep)

3. Create `infra/main.bicep` at **subscription scope** (`targetScope = 'subscription'`):
   - Parameters: `environmentName` (string), `location` (string, default `eastus2`), `isProd` (bool, derived from `environmentName`)
   - Resource suffix via `uniqueString(subscription().id, environmentName, location)` — 6 chars
   - Tags: `{ 'azd-env-name': environmentName, 'project': 'atlas-rag' }`
   - Create resource group: `rg-${environmentName}`
   - Deploy all modules into the resource group
   - Export required AZD outputs: `AZURE_RESOURCE_GROUP`, `AZURE_CONTAINER_REGISTRY_ENDPOINT`, `AZURE_KEY_VAULT_NAME`, `API_URL`

4. Create `infra/main.parameters.json` with `environmentName` and `location` as AZD-injected values using `${AZURE_ENV_NAME}` and `${AZURE_LOCATION}`.

---

## Phase 2 — Shared Services Modules

5. **`modules/monitoring.bicep`** — Log Analytics workspace + Application Insights
   - Log Analytics: SKU `PerGB2018`, retention 30 days (dev) / 90 days (prod)
   - App Insights: kind `web`, linked to Log Analytics workspace
   - Outputs: `logAnalyticsWorkspaceId`, `logAnalyticsCustomerId`, `logAnalyticsSharedKey`, `appInsightsConnectionString`, `appInsightsInstrumentationKey`

6. **`modules/managed-identity.bicep`** — User-Assigned Managed Identity
   - Name: `id-${prefix}-${token}`
   - Outputs: `identityId`, `identityPrincipalId`, `identityClientId`

7. **`modules/key-vault.bicep`** — Key Vault with RBAC authorization
   - SKU: `standard`
   - `enableRbacAuthorization: true`, `enableSoftDelete: true`, `enablePurgeProtection: true` (prod), `enabledForTemplateDeployment: true`
   - Network rules: `defaultAction: 'Allow'` (dev) / `defaultAction: 'Deny'` + private endpoint (prod)
   - Store secrets: Cosmos DB connection string, AI Search admin key (if needed), App Insights connection string

8. **`modules/container-registry.bicep`** — Azure Container Registry
   - Name: alphanumeric only (`replace('cr${prefix}${token}', '-', '')`)
   - SKU: `Basic` (dev) / `Standard` (prod)
   - `adminUserEnabled: false` (use Managed Identity + `AcrPull`)

---

## Phase 3 — AI & Data Services Modules

9. **`modules/ai-services.bicep`** — Azure AI Services (multi-model endpoint)
   - Resource type: `Microsoft.CognitiveServices/accounts`, kind: `AIServices`, SKU: `S0`
   - Deploy model: GPT-4o (name: `gpt-4o`, version: `2024-05-13`, capacity: 30K TPM dev / 80K TPM prod)
   - Deploy model: `text-embedding-ada-002` (capacity: 30K TPM)
   - Network: public access allowed (dev) / disabled with private endpoint (prod)
   - Output: `aiServicesName`, `aiServicesEndpoint`, `aiServicesId`

10. **`modules/ai-foundry.bicep`** — AI Hub + AI Project (Agent Service)
    - **AI Hub** (`Microsoft.MachineLearningServices/workspaces`, kind `Hub`):
      - Link to Key Vault, Storage Account, Container Registry, Application Insights, AI Services
      - `managedNetwork: { isolationMode: 'AllowInternetOutbound' }`
    - **AI Project** (`Microsoft.MachineLearningServices/workspaces`, kind `Project`):
      - Parent: AI Hub
      - Agent connections: Cosmos DB (thread storage), Storage Account (file storage), AI Search (vector store)
    - **Capability Host** for agents: deployed on the AI Project with `capabilityHosts/agents`
      - ⚠️ This is asynchronous (10-20 min). The Bicep will create it but AZD will need to wait for provisioning.
    - Output: `aiProjectName`, `aiProjectEndpoint`, `aiHubName`

11. **`modules/ai-search.bicep`** — Azure AI Search Service
    - SKU: `free` (dev) / `standard` (prod) — free tier limits: 50MB, 3 indexes
    - `partitionCount: 1`, `replicaCount: 1` (dev) / `replicaCount: 2` (prod, for HA)
    - Semantic search: enabled (`semanticSearch: 'free'` dev / `'standard'` prod)
    - Auth: both API key and RBAC (`authOptions: { aadOrApiKey: { aadAuthFailureMode: 'http401WithBearerChallenge' } }`)
    - Network: public (dev) / private endpoint (prod)
    - Output: `searchServiceName`, `searchServiceEndpoint`, `searchServiceId`

12. **`modules/cosmos-db.bicep`** — Cosmos DB (NoSQL / SQL API)
    - Account: `Microsoft.DocumentDB/databaseAccounts`
      - Dev: `capabilities: [{ name: 'EnableServerless' }]` — per-request billing
      - Prod: autoscale, `maxThroughput: 4000`
      - `consistencyPolicy: { defaultConsistencyLevel: 'Session' }`
      - `locations: [{ locationName: location, failoverPriority: 0 }]`
    - Database: `atlas-rag-db`
    - Container: `threads` (partition key: `/userId`)
    - Container: `conversations` (partition key: `/threadId`)
    - Network: public (dev) / private endpoint + `isVirtualNetworkFilterEnabled` (prod)
    - Output: `cosmosAccountName`, `cosmosEndpoint`, `cosmosDatabaseName`

13. **`modules/storage-account.bicep`** — Azure Storage (for Foundry file storage)
    - Name: alphanumeric, 3-24 chars
    - SKU: `Standard_LRS` (dev) / `Standard_ZRS` (prod)
    - `allowBlobPublicAccess: false`, `minimumTlsVersion: 'TLS1_2'`, `supportsHttpsTrafficOnly: true`
    - Create blob container: `agent-files`
    - Network: public (dev) / private endpoint (prod)

---

## Phase 4 — Compute Module

14. **`modules/container-apps.bicep`** — Container Apps Environment + App
    - **Environment** (`Microsoft.App/managedEnvironments`):
      - Wire `appLogsConfiguration` to Log Analytics (customerId + sharedKey)
      - Prod: deploy into VNet subnet (if private networking)
    - **Container App** (`Microsoft.App/containerApps`):
      - Identity: User-Assigned Managed Identity
      - Ingress: `external: true`, `targetPort: 8000`, `transport: auto`
      - Scale: `minReplicas: 0` (dev) / `minReplicas: 1` (prod), `maxReplicas: 10`, HTTP rule at 100 concurrent requests
      - CPU/Memory: `cpu: json('1.0')`, `memory: '2Gi'`
      - Health probes: liveness (`/health`), readiness (`/ready`), startup (`/health`)
      - Secrets injected from Key Vault via Managed Identity
      - Environment variables:
        - `AZURE_CLIENT_ID` → Managed Identity client ID
        - `APPLICATIONINSIGHTS_CONNECTION_STRING` → App Insights
        - `AZURE_COSMOS_ENDPOINT` → Cosmos DB endpoint
        - `AZURE_SEARCH_ENDPOINT` → AI Search endpoint
        - `AZURE_AI_PROJECT_ENDPOINT` → AI Foundry project endpoint
        - `AZURE_KEY_VAULT_URL` → Key Vault URI
      - Tag: `azd-service-name: api`

---

## Phase 5 — Security Module (RBAC)

15. **`modules/security.bicep`** — All role assignments in one place
    - Managed Identity → Key Vault: `Key Vault Secrets User` (`4633458b-17de-408a-b874-0445c86b69e6`)
    - Managed Identity → Cosmos DB: `Cosmos DB Built-in Data Contributor` (for read/write on thread data)
    - Managed Identity → AI Search: `Search Index Data Reader`
    - Managed Identity → AI Services: `Cognitive Services OpenAI User`
    - Managed Identity → Storage Account: `Storage Blob Data Contributor`
    - Managed Identity → Container Registry: `AcrPull`
    - Managed Identity → AI Hub/Project: `Azure AI User`
    - Each assignment uses `guid(targetResourceId, principalId, roleDefinitionId)` for idempotent naming

---

## Phase 6 — Networking (Prod Only)

16. Add a conditional `modules/networking.bicep` deployed only when `isProd == true`:
    - Create a VNet with subnets: `snet-container-apps`, `snet-private-endpoints`
    - Private endpoints for: Key Vault, Cosmos DB, AI Search, Storage Account, AI Services, Container Registry
    - Private DNS zones for each service (e.g., `privatelink.vaultcore.azure.net`, `privatelink.documents.azure.com`, etc.)
    - NSG on each subnet with least-privilege rules

---

## Phase 7 — Supporting Files

17. Create `.env.example` documenting all required environment variables for local dev.
18. Create `src/api/Dockerfile` — Python 3.11 slim, pip install requirements, uvicorn entrypoint on port 8000.
19. Create `AGENTS.md` with custom agent instructions for Copilot coding context.

---

## Verification

- **Lint**: Run `az bicep build --file infra/main.bicep` to validate syntax on every module
- **What-if**: Run `az deployment sub what-if --location eastus2 --template-file infra/main.bicep --parameters infra/main.parameters.json` to preview changes without deploying
- **AZD provision (dev)**: `azd env new macu-atlas-dev && azd provision` to deploy dev environment
- **AZD provision (prod)**: `azd env new macu-atlas-prod && azd provision` with prod parameter overrides
- **Post-deploy checks**: Verify each resource exists in portal, confirm Managed Identity has correct RBAC via `az role assignment list --assignee <principalId>`, test Container App health endpoint

---

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| IaC recipe | AZD + Bicep | `azd up` orchestration, env management, CI/CD generation |
| Identity model | User-Assigned Managed Identity | Single identity shared across Container App → all backends; easier to pre-assign RBAC before app deployment |
| main.bicep scope | Subscription | Creates the resource group itself, making the deployment fully self-contained |
| RBAC location | Single `security.bicep` | Centralizes role assignments for auditability (regulated industries) |
| Cosmos DB tier | Serverless (dev) / Autoscale (prod) | Cost optimization for dev, predictable performance for prod |
| AI Search tier | Free (dev) / Standard (prod) | Sufficient for development; standard for hybrid + semantic ranking at scale |
| Region | `eastus2` | Strong GPT-4o + embeddings availability. Override to `northcentralus` if hosted agents preview is needed |
| Private endpoints | Prod only | Balances security for regulated industries with development agility |
| Storage account | Separate module | Required by AI Foundry Agent Service for file storage (distinct from app blob needs) |
