# MRMS System Knowledge Base
**Generated:** 2026-04-29  
**Purpose:** Complete system knowledge for documentation generation sessions.  
**Covers:** Architecture, repos, code, config, deployments, operations, known issues.

---

## 1. SYSTEM IDENTITY

- **Full name:** Mandate Review and Management System (MRMS)
- **Organisation:** United Nations Office at Geneva (UNOG)
- **Tenant:** UN OICT Microsoft 365 tenant — `unitednations.sharepoint.com`
- **Tenant ID:** `0f9e35db-544f-4f60-bdcc-5ea416e6dc70`
- **Platform:** SharePoint Online (SPFx web parts) + Power Automate + Azure Functions (Python) + Power BI + Azure Key Vault (certificate storage for MSAL auth)
- **Purpose:** Manages the full lifecycle of intergovernmental meeting resolutions — ingestion, data entry, PBI cost calculations, approval workflows, oral statement generation, revised estimate reporting, and mandate tracking.

---

## 2. ENVIRONMENTS

| Environment | SharePoint Site URL | Purpose |
|---|---|---|
| DEV (Stage) | `https://unitednations.sharepoint.com/sites/APP-STAGING-MRMS-MGT_DEV` | Development & integration testing |
| UAT | `https://unitednations.sharepoint.com/sites/UAT-MRMS-MGT` | User acceptance testing |
| PROD | `https://unitednations.sharepoint.com/sites/mrms-mgt` | Live production |

Each environment is fully isolated — separate site collection, separate Power Automate flows, separate Azure Function instance.

---

## 3. REPOSITORIES

| Repo | Local Path | Purpose |
|---|---|---|
| section2 | `C:\Repos\MRMS\section2` | SPFx solution — Resolution forms and PBI entry |
| mandatedashboard | `C:\Repos\MRMS\mandatedashboard` | SPFx solution — Mandate dashboard, User dashboard, RE Report, Permission check |
| ospython | `C:\Repos\MRMS\ospython` | Azure Functions — Python 3.11 backend |

---

## 3.1 TECHNOLOGY VERSIONS & LICENSING

| Component | Version | Licence / Notes |
|---|---|---|
| SharePoint Online | Latest (Microsoft 365 SaaS — always current) | M365 E3 per-user — managed by UN OICT |
| Power Automate | Latest (Microsoft 365 SaaS) | Standard connectors: included in M365 E3; HTTP connector/trigger (Premium): requires Power Automate Premium per-user or per-flow plan |
| SPFx Framework | 1.18.x (sp-core-library 1.18.1 / 1.18.2) | Included with SharePoint Online |
| React | 17.0.1 | SPFx 1.18 supported version; MIT licence |
| PnP JS (`@pnp/sp` + `@pnp/graph`) | ^3.20.1 | MIT licence |
| FluentUI React | ^8.106.4 (MRMS-Forms) / ^9.61.6 (MRMS-Dashboards) | MIT licence |
| TypeScript | 4.7.4 | Apache-2.0; SPFx compile-time only |
| Node.js | 18.18.2 (CI build) | LTS — build-time only, not runtime |
| Gulp | 4.0.2 | Build tool |

### Power Automate — Bills of Materials / Licensing

| Flow | Connector Tier | Licence Required | Cost Note |
|---|---|---|---|
| MRMS -Resolution-WF | **Premium** (HTTP connector) | Power Automate Premium per-user or per-flow plan | ~£12.30/flow/month (UN EA pricing may vary) |
| MRMS System Status List Update | **Premium** (HTTP trigger) | Power Automate Premium per-user or per-flow plan | ~£12.30/flow/month (UN EA pricing may vary) |
| MRMS ResolutionWF – Bulk Email | Standard (Office 365 Outlook + SharePoint) | Included in M365 E3 | No additional cost |
| MRMS Email Notifications workflow | Standard (Office 365 Outlook + SharePoint) | Included in M365 E3 | No additional cost |

**Minimum licensing requirement:** One Power Automate Premium licence assigned to the MRMS service account (covers all Premium flows run under that account), or per-flow plans for the two Premium flows.

---

## 4. SPFx SOLUTION: section2 (MRMS-Forms)

### Package metadata
- **Solution name:** `MRMS-Forms`
- **Solution ID:** `0e86565d-5e33-48ea-b20d-9cd72268f9b6`
- **Package file:** `sharepoint/solution/mrms-forms.sppkg`
- **Version:** `2.0.0.0`
- **SPFx version:** 1.18.x (sp-core-library: 1.18.1)
- **Node.js engine:** `>=16.13.0 <17.0.0 || >=18.17.1 <19.0.0` (CI uses 18.18.2)
- **includeClientSideAssets:** false (bundles go to CDN library)
- **skipFeatureDeployment:** true

### Web parts
| Web Part | Class | Manifest ID | Purpose |
|---|---|---|---|
| Section2 | `Section2WebPart` | section2 | Resolution dashboard / overview for Section 2 (DGACM/Conference Services) |
| Section24 | `Section24WebPart` | section24 | PBI form for Section 24 (OHCHR) |
| AddResolution | `AddResolutionWebPart` | addResolution | Add/Edit resolution form |
| Miscellaneous | `MiscellaneousWebPart` | miscellaneous | PBI form for Miscellaneous budget sections |
| BulkUploads | `BulkUploadsWebPart` | bulkUploads | Bulk update / batch field updates across resolutions |

### Source tree (`src/`)
```
common/
  Constants.ts          — All column config arrays (ISRMandateListColumns, IDocumentsListColumns, IMeetingsListColumns, blank table templates, button/dropdown styles)
  CommonUtility.ts      — Shared utility functions incl. writeErrorLog()
  Utility.ts            — Additional helpers
  DatePickerWithClear.tsx
  OperativeParaDialog.tsx
  ReplicateDialog.tsx
  PopUpValues.json

components/             — Reusable PBI form row components
  consultantexperts/    — ConsultantExperts.tsx
  documentservice/      — Documents.tsx
  meetingservice/       — NewMeetings.tsx
  otherservices/        — OtherServices.tsx
  postnstaff/           — PostsnStaffCosts.tsx
  srmandate/            — SRMandateNew.tsx, SRMandateDefaultValue.tsx
  travel/               — Travel.tsx
  rowheader/            — RowHeader.tsx
  rowheadercolumns/     — RowHeaderColumns.tsx
  totalcostheader/      — TotalcostbyearHeader.tsx
  leftnavigation/       — SideNavNode.tsx
  targetaudience/       — TargetAudience.tsx

models/
  IConfig.ts            — Config file interfaces (IModal, etc.)
  ICostConfig.ts        — CostRates config structure
  IOSInterfaces.ts      — Oral Statement data interfaces
  IResolution.ts        — Resolution list item interface
  ISideNavItem.ts / ISideNavNode.ts — Navigation models
  ITablesConfig.ts      — PBI table row interfaces (ISRMandateNewTable1, INewMeetingTable, INewTravelTable3, IConsultentExpertsTable2, etc.)
  SPException.ts        — Error exception model

services/
  DataService.tsx       — All SharePoint REST API calls via PnP JS (1130 lines)
                          getData(), getDatalkp(), getDataWithSelect(), createItem(), updateItem(), deleteItem(), getUser(), getUserGroups(), batch operations
                          Static: userGroups[] list, BATCH_SIZE=20, MAX_RETRIES=5
  CostRatesService.tsx  — Reads CostRates Excel via PnP JS getFileByServerRelativePath().getBuffer() + SheetJS (xlsx) parse (230 lines)
                          Get(fileLocation), readFileContent(fileBuffer), GetResData(resId)
  ApprovalService.tsx   — Reads approval chain from CostRates workbook Approvals sheet; resolves current user's groups; determines next approver
  CustomLogger.ts       — ILogListener implementation (PnP logging); writes to Error Logs SharePoint list
                          LogData, LogItem interfaces; fields: ApplicationName, CodeFileName, MethodName, LoggedOn, LoggedById, ErrorMessage, StackTrace
  DialogService.tsx     — SPFx dialog helper
  
startup/
  Startup.ts            — PnP JS SPFI initialisation: getSP(context?) — singleton pattern, SPFx + PnPLogging(Warning)
  AppContext.tsx         — React Context provider (SPApp, SPAppContextProvider)
                          Exposes: Context (SPFI), GetPageContext, DataService, CostRateService, ApprovalService
                          Also exports: CustomLogging(webpartName, ctx, listName) — activates CustomLogger at Error level

webparts/
  section2/Section2WebPart.ts       — BaseClientSideWebPart; properties: fileLocationUrl, locationsUrl, defaultValueUrl, notificationWFUrl, siteUri
  section24/Section24WebPart.ts     — Similar property pane
  addResolution/AddResolutionWebPart.ts
  miscellaneous/MiscellaneousWebPart.ts
  bulkUploads/BulkUploadsWebPart.ts
```

### Key dependencies
```json
"@microsoft/sp-webpart-base": "^1.18.2",
"@pnp/sp": "^3.20.1",
"@pnp/graph": "^3.20.1",
"@fluentui/react": "^8.106.4",
"camljs": "^2.13.0",
"file-saver": "^2.0.5",
"gulp-spsync": "^1.5.9",
"xlsx": "(via SheetJS — for CostRates Excel reading client-side)"
```

### Build & deploy (gulpfiles)
- `gulpfile.js` — main; suppresses SASS warnings; requires all gulpfile-* tasks
- `gulpfile-upload-app-package.js` — `upload-app-pkg` task: uploads `.sppkg` to `AppCatalog` library using certificate-based auth. Args: `--clientId`, `--certPath`, `--certPassword`, `--tenantId`, `--tenant`, `--catalogsite`
- `gulpfile-deploy-app-package.js` — `deploy-app-pkg` task: triggers deployment of the uploaded `.sppkg` in the App Catalog via SharePoint REST API, using certificate JWT assertion (Entra ID). Args: same as upload-app-pkg
- `gulpfile-upload-to-sharepoint.js` — `upload-to-sharepoint` task: uploads `dist/**/*.*` to CDN library. Args: `--clientId`, `--certPath`, `--certPassword`, `--tenantId`, `--tenant`, `--cdnsite`, `--cdnlib`

### Bitbucket Pipeline
```yaml
image: node:18.18.2
pipelines:
  default:
    - step:
        name: Deploy to Stage
        deployment: STAGE
        caches: [node]
        script:
          - npm install
          - npm install -g gulp
          - gulp clean
          - gulp bundle --ship
          - gulp package-solution --ship
          - echo $CertificateBase64 | base64 --decode > /tmp/pipeline-cert.pfx
          - gulp upload-app-pkg --ship --clientId $Stage_AzureAppRegClientId --certPath /tmp/pipeline-cert.pfx --certPassword $CertificatePassword --tenantId $AzureTenantId --tenant $Tenant --catalogsite $Stage_Site
          - gulp deploy-app-pkg --ship --clientId $Stage_AzureAppRegClientId --certPath /tmp/pipeline-cert.pfx --certPassword $CertificatePassword --tenantId $AzureTenantId --tenant $Tenant --catalogsite $Stage_Site
          - gulp upload-to-sharepoint --ship --clientId $Stage_AzureAppRegClientId --certPath /tmp/pipeline-cert.pfx --certPassword $CertificatePassword --tenantId $AzureTenantId --tenant $Tenant --cdnsite $Stage_Site --cdnlib $AppResources
```
**Pipeline variables:** `Stage_AzureAppRegClientId`, `CertificateBase64`, `CertificatePassword`, `AzureTenantId`, `Tenant`, `Stage_Site`, `AppResources`  
**Auth:** Certificate decoded from `$CertificateBase64` at pipeline runtime — no client secret.  
**Note:** Only STAGE step configured. DEV/UAT/PROD must be added separately.

### Local development
```
config/serve.json — port 4321, https, initialPage: https://{tenantDomain}/_layouts/workbench.aspx
```

---

## 5. SPFx SOLUTION: mandatedashboard (MRMS-Dashboards)

### Package metadata
- **Solution name:** `MRMS-Dashboards`
- **Solution ID:** `e76bad73-ca42-4e4e-8b1a-2bd5e3a2ab71`
- **Package file:** `sharepoint/solution/mrms-dashboards.sppkg`
- **Version:** `2.0.0.0`
- **skipFeatureDeployment:** false
- **Node.js engine:** `>=18.17.1 <19.0.0` (CI uses 18.18.2)

### Web parts & extensions
| Component | Class | Type | Purpose |
|---|---|---|---|
| mdashboard | `MdashboardWebPart` | Web part | Mandate dashboard — resolution/mandate overview, OS Reports, Approval progress |
| userDashboard | `UserDashboardWebPart` | Web part | Personal dashboard — user's pending items; tab caching |
| revEstReport | `RevEstReportWebPart` | Web part | Revised Estimate report generation UI; calls Azure Function `/api/generate_revest` |
| PermissionCheckApplicationCustomizer | `PermissionCheckApplicationCustomizer` | Application Extension | Runs on ALL site pages; reads `SitePermissions` list; redirects unauthorised users away from admin pages |

### PermissionCheckApplicationCustomizer detail
- Extends `BaseApplicationCustomizer`
- Renders `CheckAccess` React component into the Top placeholder
- Reads `SitePermissions` list to determine restricted page patterns
- Redirects users if current URL matches restricted patterns (Resolutions, viewlsts, /Lists/, /Forms/, CreateSitePage.aspx, sitepagepreview.aspx, user.aspx, siteanalytics.aspx)
- Feature ID: `6ba8bba6-a41c-4fbd-b343-daa89abe7091`

### Source tree (`src/`)
```
extensions/
  permissionCheck/
    PermissionCheckApplicationCustomizer.ts — BaseApplicationCustomizer; renders into PlaceholderName.Top; uses getSP() from services/pnpjsConfig
    CheckAccess.tsx                          — React component; reads SitePermissions list; performs redirect

models/
  constants.tsx         — Constants specific to mandatedashboard
  IConfig.ts            — Config interfaces
  ISideNavItem.ts / ISideNavNode.ts / ISideNavNodeProps.ts / ISideNavNodeState.ts — Navigation
  ReadMoreReadless.tsx  — UI component

services/
  pnpjsConfig.ts        — getSP(context?) singleton (same pattern as section2/Startup.ts)
  AppContext.tsx         — SPAppContextProvider (same pattern as section2/AppContext.tsx)
                          Exposes: Context, GetPageContext, DataService, CostRateService, ApprovalService
  DataService.tsx       — SharePoint REST API calls
  CostRatesService.tsx  — Excel reading via PnP + SheetJS
  ApprovalService.tsx   — Approval chain resolution
  ApprovalProgressBar.tsx / ApprovalTimeline.tsx — UI approval tracking components
  SummTableService.tsx  — Summary table generation service
  CustomLogger.ts       — Same pattern as section2
  DialogService.tsx

utilities/
  CommonUtility.ts
  ReadMoreComments.tsx

webparts/
  mdashboard/
    MdashboardWebPart.ts
    components/
      Mdashboard.tsx        — Main dashboard component
      Dashboard.tsx         — Resolution/mandate list view; lazy loading ~20 items
      DetailsPage.tsx       — Resolution detail view
      Reports.tsx / Reports1.tsx — Reporting views
      OSReports.tsx         — Oral Statement reports view
      OSInterfaces.tsx      — OS data interfaces
      Constant.ts           — Dashboard-specific constants
  revEstReport/
    RevEstReportWebPart.ts
    components/
      RevEstReport.tsx      — Main RE report component; calls Azure Function /api/generate_revest
      RevEstReportDetails.tsx
      AllResNavigator.tsx   — Navigate across all resolutions
      REInterfaces.tsx      — RE data interfaces
      dragable.tsx          — Draggable UI component
  userDashboard/
    UserDashboardWebPart.ts
    components/
      UserDashboard.tsx     — Tab-based personal dashboard; implements tab caching
```

### Key dependencies
```json
"@microsoft/sp-application-base": "^1.18.2",
"@fluentui/react": "^8.106.4",
"@fluentui/react-components": "^9.61.6",
"@pnp/sp": "^3.20.1",
"axios": "^0.21.0",
"@gooddata/sdk-ui-pivot": "^8.1.0"
```

---

## 6. AZURE FUNCTIONS: ospython

### Runtime & config
- **Language:** Python 3.11
- **Model:** Azure Functions v2 programming model (blueprint-based)
- **Extension bundle:** `[4.*, 5.0.0)`
- **host.json:** Functions v2.0, Application Insights sampling enabled (excludes Request type)
- **Entry point:** `function_app.py`
- **Shared auth module:** `sp_auth.py` — centralises all SharePoint authentication; all functions call `get_sp_context()` instead of inline MSAL code

### Registered functions (host.json)
`generate_os_files`, `generate_doc_in_memory`, `upload_to_SP`, `parser`, `generate_revest`

### Four callable functions

#### 6.1 generate_os_files (`function_app.py`)
- **Route:** `POST /api/generate_os_files`
- **Auth level:** Function
- **Purpose:** Generates Oral Statement Word document from resolution JSON; uploads to SharePoint
- **Auth method:** Entra ID App Registration — certificate-based MSAL (`msal.ConfidentialClientApplication`); loads certificate from `Certificates/mrms-prod.pfx`
- **Template:** `Templates/OSTemplate_MRMS_1.docx`
- **Output path:** `Resolutions/{draftResNo_sanitized}/OralStatement_{draftResNo}_{timestamp}.docx`
- **SharePoint property set:** `TypeofFile = "System Generated"`
- **Env vars:** `uat_TenantID`, `uat_ClientID`, `uat_Url`, `uat_CertPassword` (read via `sp_auth.get_sp_context()`)
- **MSAL flow:** `msal.ConfidentialClientApplication` with certificate thumbprint + private key PEM; acquires token for `{sp_root}/.default`; uploads via `Office365-REST-Python-Client`

#### 6.2 parser (`http_parser.py`)
- **Blueprint:** `parser_bp` — registered in `function_app.py`
- **Route:** `POST /api/parser`
- **Auth level:** Function
- **Purpose:** Extracts Operative Paragraphs from a DOCX file (base64 bytes or UN document symbol URL)
- **Auth method:** Entra ID App Registration — certificate-based MSAL via `sp_auth.get_sp_context()`; env vars: `uat_TenantID`, `uat_ClientID`, `uat_Url`, `uat_CertPassword`
- **Process:**
  1. Reads CostRates library — finds file with `TypeofFile="CostRates"` and valid dates
  2. Reads `ParsingTransform` sheet → loads `keywords[]` and `Transform_keywords[]` from row 2 (comma-separated Parse and Transform columns)
  3. If `AdoptedResolution` in body: downloads from `https://documents.un.org/api/symbol/access?s=...&l=en&t=doc`
  4. Otherwise: decodes `bytes` field from request body
  5. Runs `extract_text_from_docx()` — uses NLTK + textblob + regex normalisation
  6. Returns HTTP 201 with JSON array of operative paragraphs
- **Text normalisation:** `clean_text_plus()` — handles OP/PP numbering variants (OP1, OP.1, (1), 1), etc.
- **Returns:** JSON array of `{"original": "..."}` objects (if AdoptedResolution path) or raw JSON array

#### 6.3 generate_revest (`http_rer.py`)
- **Blueprint:** `revest_bp` — registered in `function_app.py`
- **Route:** `POST /api/generate_revest`
- **Auth level:** Function
- **Purpose:** Generates both a Word (.docx) and Excel (.xlsx) Revised Estimate report in memory; uploads both to SharePoint `RevEstReports` library
- **Auth method:** Entra ID App Registration — certificate-based MSAL via `sp_auth.get_sp_context()`; env vars: `uat_TenantID`, `uat_ClientID`, `uat_Url`, `uat_CertPassword`
- **Reading:** `year` from query params
- **Word template:** `Templates/RevisedEstTemplate_MRMS.docx` — rendered via `DocxTemplate` (Jinja2)
- **Excel:** Built programmatically with `openpyxl`; creates "Annex I PartB" sheet with merged cells, borders, dynamic year columns (`year1`, `year2` extracted from data)
- **Output upload:** Both files uploaded to `RevEstReports` library
- **Returns:** `{"word_file": "<url>", "excel_file": "<url>"}`

### File structure
```
ospython/
  function_app.py           — Entry point; registers parser_bp and revest_bp; imports get_sp_context from sp_auth
  sp_auth.py                — Shared auth module: get_sp_context(sp_url?) — authenticates via Entra ID App Registration (certificate MSAL), returns ClientContext
  http_parser.py            — OP extraction blueprint
  http_rer.py               — RE generation blueprint
  host.json
  requirements.txt
  local.settings.json       — Local dev env vars (not committed)
  settings.json             — DEV credentials in plaintext (SECURITY ISSUE — must remove; KI-002 in dev doc)
  Appreg.txt                — DEV app registration details in plaintext (SECURITY ISSUE — must remove; KI-002 in dev doc)
  Templates/
    OSTemplate_MRMS_1.docx
    RevisedEstTemplate_MRMS.docx
    ExcelTemplateAnnexIPartB.xlsx
  Certificates/
    mrms-prod.cer  (also referenced as mrms-cert.cer in Maintenance Guide)
    mrms-prod.pfx  (also referenced as mrms-cert.pfx in Maintenance Guide) — certificate moved to Azure Key Vault (KI-005 COMPLETED)
```

### requirements.txt
```
azure-functions
docxtpl
Office365-REST-Python-Client
msal
cryptography
python-dateutil
pdf2docx
docx
python-docx
openpyxl
nltk
textblob
docx2python
beautifulsoup4
```

### Application Settings (all environments)
| Setting | DEV | PROD |
|---|---|---|
| `FUNCTIONS_WORKER_RUNTIME` | python | python |
| `AzureWebJobsStorage` | UseDevelopmentStorage (local only) | production storage conn string |
| `uat_TenantID` | `0f9e35db-544f-4f60-bdcc-5ea416e6dc70` | same |
| `uat_ClientID` | `6746d574-090f-4a0b-9123-3410754d6333` | `cb179fd2-7cdc-463c-a5cb-7b34f1ddca94` |
| `uat_Url` | `https://unitednations.sharepoint.com/sites/APP-STAGING-MRMS-MGT_DEV` | `https://unitednations.sharepoint.com/sites/mrms-mgt` |
| `uat_CertPassword` | DEV cert password | PROD cert password |

### local.settings.json template
```json
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "uat_TenantID": "0f9e35db-544f-4f60-bdcc-5ea416e6dc70",
    "uat_ClientID": "<App Registration Client ID>",
    "uat_Url": "https://unitednations.sharepoint.com/sites/APP-STAGING-MRMS-MGT_DEV",
    "uat_CertPassword": "<certificate password>"
  }
}
```

---

## 7. APP REGISTRATIONS

| Environment | App Name | Client ID | Auth Method |
|---|---|---|---|
| DEV | PythonApp | `6746d574-090f-4a0b-9123-3410754d6333` | Entra ID App Registration — certificate-based MSAL (all 3 functions) |
| PROD | MRMS-Forms PROD | `cb179fd2-7cdc-463c-a5cb-7b34f1ddca94` | Entra ID App Registration — certificate-based MSAL (all 3 functions) |

- **Tenant ID (all):** `0f9e35db-544f-4f60-bdcc-5ea416e6dc70`
- **Required API permission:** SharePoint → Sites.FullControl.All (application permission, admin consented)
- **Auth flow:** `msal.ConfidentialClientApplication` with PFX certificate; acquires token for `https://unitednations.sharepoint.com/.default`
- **No client secrets used** — all environments authenticate via certificate only

---

## 8. SHAREPOINT DATA MODEL

### Lists & Libraries
| Name | Type | Key Columns | Purpose |
|---|---|---|---|
| Resolutions | Document Set Library | DraftRes, Session, AdoptedRes, ResTitle, OPPara, SessionYear, IntergovtBody, TypeofFile, DefaultValuesFrom, CostrateValuesFrom | Core resolution registry; each resolution is a Document Set |
| Mandates | List | MandateID, ResolutionID (lookup), MandateTitle, MandateType, StartDate, EndDate, BudgetSection, Status | Mandate records per resolution |
| OPs (OperativeParagraphs) | List | OPID, MandateID (lookup), ResolutionID (lookup), OPNumber, OPText, ParsedKeyword | Extracted operative paragraphs |
| PBI — Conference Services (MeetingsServices, DocumentServices) | Lists | MandateID, ResolutionID, BudgetSectionID, TotalCosts | Conference Services PBI entries |
| PBI — OHCHR/Misc (PostnStaffCosts, TravelandContributions, ConsultantExperts, OtherServices) | Lists | MandateID, ResolutionID, BudgetSectionID, TotalCosts, ApprovedTotalCosts, Quantity, frequency, location, type, recurrency | OHCHR and other budget section PBI entries |
| SR_MandateExtension | List | MandateID, TotalDoc | SR mandate extensions; used in approval condition SR_MANDATE |
| Status | List | ResolutionID, Stage, ApprovedBy, ApprovedDate, ApprovalStatus (Choice) | Approval workflow status per resolution/PBI |
| CostRates | Document Library | TypeofFile, EffectiveFromDate, ValidTillDate | Stores MRMSRates and DefaultValues Excel files |
| Resolutions (Documents) | Document Library | TypeofFile | Generated OS .docx files under `Resolutions/{draftResNo}/` |
| RevEstReports | Document Library | (standard) | Generated RE Word and Excel files |
| Documents/Templates | Sub-folder in Documents | — | Word/Excel templates for Azure Functions |
| AppResources | Document Library | — | CDN library for SPFx JS bundles |
| ErrorLogs | List | ErrorID, WebPart, ErrorMessage, StackTrace, UserLogin, Timestamp, ResolutionID, Severity, Resolved | SPFx client-side error log |
| UserEmails | List | Email, Group, NotificationType | Notification recipients |
| EmailTemplatesHRC | List | Subject, Body, TemplateType | Email templates for bulk notifications |
| BulkUpdateFiles | Document Library | — | Staging library for bulk update uploads |
| MiscellaneousPbi | List | (form-specific) | Required by Miscellaneous web part |
| SafeList | List | (email senders) | Whitelisted sender emails for ingestion flow |
| SitePermissions | List | (page pattern rules) | Read by PermissionCheck extension to determine page restrictions |
| Status (UserEmails) | List | — | Used by My Dashboard to show pending approvals and all resolution statuses |

### Data relationships
```
Resolutions (Document Set)
  └── Mandates (ResolutionID lookup)
        ├── OPs (MandateID lookup)
        └── PBI Lists (MandateID + BudgetSectionID)
              └── Status (ResolutionID)
```

### Indexes (required on Resolutions list)
Session, SessionYear, IntergovtBody, TypeofFile, ResolutionID, MandateID, BudgetSectionID, Created

### SharePoint Search — Managed Properties
| Property | Type | Queryable | Retrievable |
|---|---|---|---|
| DraftRes | Text | Yes | Yes |
| Session | Number | Yes | Yes |
| AdoptedRes | Text | Yes | Yes |
| ResTitle | Text | Yes | Yes |
| OPPara | Text | No | Yes |
| SessionYear | Number | Yes | Yes |
| IntergovtBody | Text | Yes | Yes |

**Result Source:** `Resolutions_Dashboard` — queries Resolutions list by ContentType and Path

---

## 9. COSTRATES EXCEL WORKBOOK

- **File naming:** `MRMSRates_YYYY.xlsx` (e.g. `MRMSRates_2026.xlsx`)
- **Library:** CostRates SharePoint document library
- **Selection logic:** `TypeofFile = "CostRates"` AND `EffectiveFromDate <= today <= ValidTillDate`; first matching file is used
- **Versioning:** Enabled — all versions retained (audit requirement — linked via DefaultValuesFrom / CostrateValuesFrom)
- **Total sheets:** 56
- **Access:** Only MRMS Owners group may upload

### Sheet groups (9 groups)

**Group 1 — Tabs Update Guide**
- Sect. 24 OHCHR Tabs List, Sect. 2 DGACM Tabs List, Sect. 28-29E DGC-DoA Tabs List

**Group 2 — Reference Lookup Tables (annual update)**
- Locations, Travel rates, DSA rates, Terminal exp, Salary scales, Salary scales ALL, Salary scales DGACM, Salary scales (2022), Exchange rates, Job Codes, Entities, Budget Section vs ENTITY list, DS

**Group 3 — Cost Rates (per entity)**
- Cost_Rates OHCHR (Section 24), Cost_Rates OLA (Section 8), Cost_Rates DGACM (Section 2), Cost_Rates DGC (Section 28), Cost_Rates DSS (Section 34), Cost_Rates UNOG (Section 29E), Cost_Rates ALL
- Standard columns: Resource Category, Resource Subcategory, Item/Location, Servicing Duty Station, Budget Class, Commitment Item, Entity/Entity Name, Budget Section, Cost Center, Currency (USD), Unit rate, Unit (YEAR/DAY/WORD/HOUR/MONTH), Calculation Formula, Comments

**Group 4 — Approval Chain Configuration**
- **Approvals sheet columns:** BudgetSectionName, Entity, Draft, CanRecall, DeletePBI, CONDITIONS, Order, WF (SharePoint group), AddNotification
- **Defined chains:** Section 24 (OHCHR), CONFSERV (Conference Services), OS (Oral Statement), Section 8 (OLA)
- **Condition codes:** SR_MANDATE, STD_DOC, NONSTD_DOC, ACCESSIBILITY, WEBCASTING, AUDIO_REC, NON_GVA, INTRP_LESSTHAN6, POST_GTA_12M_GVA
- **ApprovalDetails(Draft)** sheet — documents condition code logic

**Group 5 — Form Configuration (per entity)**
- DropdownValues ALL, DropdownValues OHCHR-General, DropdownValues DGACM, DropdownValues UNOG
- Headers OHCHR-MISC, Headers DGACM, Headers ALL
- Categories OHCHR-MISC
- Standard Values OHCHR, Standard Values DGACM, Standard Values ALL, DefaultValues DGACM
- CostFormula OHCHR, CostFormula DGACM, CalculationFormulas

**Group 6 — Application/System Mappings**
- SummaryTable — master mapping: BudgetSection → Form type → BudgetSectionName → Entity → BudgetSectionID → SharePoint List names
- ConfServForm_Mappings — Conference Services field-to-list mappings (Type=General and Type=RevisedEstimates)

**Group 7 — Document Generation Values**
- OS values — Item#, FIELD_name, VALUE — static OS template field values (GA session number, recipient/sender name/position, Cc)
- RE values — Item#, FileTemplate, FIELD_name, VALUE, Comment — RE template field values (session dates, HRC report symbols, staff assessment %)
- RE values Annex III — historical data for RE statistical summary

**Group 8 — OP Parsing Configuration**
- ParsingTransform — Parse column (trigger verbs, comma-separated) + Transform column (normalised output verbs)
- Row 2 is loaded at runtime by `http_parser.py`

**Group 9 — Sample Form Templates**
- Sect 2 (Conference Services), Sect 24 (Human Rights), Sect 29E (Administration), Miscellaneous PBI, Details breakdown — not consumed by application at runtime

### Annual update mandatory sheets
Salary scales, Travel rates, DSA rates, Terminal exp, Exchange rates, OS values, RE values

---

## 10. POWER AUTOMATE FLOWS

| Flow Name | Trigger | Premium? | Purpose |
|---|---|---|---|
| MRMS -Resolution-WF | Email arrival (mrms@un.org) | **Yes — HTTP connector (Premium)** | Key connections: Office 365 Outlook, SharePoint, HTTP | Ingests resolutions; creates/updates Resolutions list; handles new, revision, amendment, correction, withdrawal scenarios |
| MRMS ResolutionWF – Bulk Email | Email arrival | No — Standard (M365 E3) | Key connections: Office 365 Outlook, SharePoint | Bulk amendment/withdrawal notifications using EmailTemplatesHRC |
| MRMS Email Notifications workflow | Email arrival / called from other flows | No — Standard (M365 E3) | Key connections: Office 365 Outlook, SharePoint | Reusable notification flow; reads UserEmails list |
| MRMS System Status List Update | Status list item (without version update) | **Yes — HTTP trigger (Premium)** | Key connections: SharePoint, HTTP, Approval | Updates Status list item for Resolution, DCMPBI, OHCHROtherPBI fields without version increment |

> ⚠️ **Known inconsistency (doc §7.1 Table):** The "Premium Connector?" column in Section 7.1 still shows "No" for MRMS -Resolution-WF and MRMS System Status List Update. Section 7.4 (Licensing & BOM table) correctly identifies them as Premium. The §7.1 column should be updated to "Yes" in a future doc revision.

**Connection owner:** All PROD/UAT connections must be owned by MRMS service account (not personal accounts). A backup owner with equal access should be assigned for each connection.
**Premium connector licensing:** At least one per-user plan or per-flow plan is required for flows using HTTP actions or Word Online Business connectors.
**Run history retention:** 28 days (platform default)

---

## 11. SHAREPOINT PERMISSION MODEL

### Groups & permissions
| Group | Permission Level | Key Access |
|---|---|---|
| Site Owners (MRMS Owners) | Full Control | All site content; can upload CostRates; manage groups |
| OHCHR Finance | CustomEdit | Finance-related PBI forms |
| OHCHR Focal Point | CustomEdit | OS initiation; Generate OS button visible |
| OHCHR Substantive Staff | CustomEdit | Resolution data entry; Generate OS button visible |
| DCMEO | CustomEdit | DCMEO PBI sections |
| DCMMMS | CustomEdit | DCMMMS PBI sections |
| PPBD FBO | CustomEdit | PBI approval (PPBD FBO stage); OS approval |
| PPBD | CustomEdit | Final PBI and OS approval |
| Site Contributors | Edit | General edit access |
| Site Visitors | Read | Read-only |

### User management
- **PowerApps app** accessible from top navigation of MRMS site
- Focal Points can add/remove users and assign roles without Site Admin involvement
- App automatically adds users to correct SharePoint groups for selected role

### Object-level overrides
- CostRates Library — restricted to MRMS Owners
- SafeList — restricted to MRMS Administrators and Owners
- SitePermissions list — read by PermissionCheck extension; redirects unauthorised users

---

## 12. AUTHENTICATION FLOWS

### Current (implemented)
- **All three Azure Functions (generate_os_files, parser, generate_revest):** Entra ID App Registration — certificate-based MSAL (`msal.ConfidentialClientApplication`); PFX certificate loaded at runtime; acquires token for `https://unitednations.sharepoint.com/.default`; no client secrets used
- **Env vars required:** `uat_TenantID`, `uat_ClientID`, `uat_Url`, `uat_CertPassword`
- **SPFx → SharePoint:** Native SharePoint Online authentication (user context)
- **SPFx → Azure Functions:** HTTP call with Function key (`code=` query param)

---

## 13. CI/CD

- **Tool:** Bitbucket Pipelines (also referenced as GitHub Actions / Bitbucket DevOps in Design Doc)
- **Both SPFx repos:** node:18.18.2 Docker image
- **Current state:** DEV/Stage pipeline configured (auto-deploy on branch push); UAT/PROD pipeline steps NOT yet configured (KI-006)
- **Azure Functions:** Manual deployment via VS Code Azure Functions extension (no pipeline) — sign in with Service Account
- **Merge to Dev/Stage/UAT branches** → triggers deployment process; automatically uploads resources and .sppkg file
- **UAT/PROD SPFx:** Manual — upload .sppkg to App Catalog, then Deploy in App Catalog UI
- **Configuration differences between environments:** Bitbucket repository variables only (no code differences)

---

## 14. PROCESS FLOWS

### Resolution lifecycle states
Draft → Approved → (Withdrawn | Amended | Corrected)  
Also: Rejected (returned for rework)

### PBI approval stages
1. Requested
2. Revised Estimate
3. ACABQ
4. GA Approved

### Oral Statement approval stages (per Approvals sheet — Section 24 / OS chain)
1. OHCHR Substantive Staff / Division
2. PBI Focal Point
3.1 Finance Reviewer
3.2 Finance Approver
4. PPBD FBO
5. PPBD OD

Return at any stage resets OS status and notifies the relevant party.

### Data lineage
1. Resolution created (manual via AddResolution form OR auto via email ingestion flow)
2. OPs extracted (Power Automate → Azure Function `/api/parser` → saves OPs to SharePoint)
3. User associates OPs with Mandates on Edit Resolution page
4. PBIs entered per mandate by relevant teams
5. PBIs progress through approval chain (read from CostRates Approvals sheet at runtime)
6. OS generated (Generate button → Azure Function `/api/generate_os_files` → DOCX → uploaded to Resolutions/{draftResNo}/)
7. OS approval chain runs
8. RE report generated (Revised Estimate web part → Azure Function `/api/generate_revest` → Word + Excel → uploaded to RevEstReports/)
9. Power BI reads Resolutions, Mandates, OPs, PBI lists for reporting

---

## 15. TO-BE / FUTURE ITEMS

| Item | Description | Status |
|---|---|---|
| Entra ID App Registration auth | Replace client secrets with certificate-based MSAL for all Azure Functions | **COMPLETED** |
| Certificate PFX in source control | Move PFX certificate from `ospython/Certificates/` to Azure Key Vault | **COMPLETED** (KI-005) |
| Application Insights | Connect Azure Function App to Application Insights | **COMPLETED** (KI-006) |
| OS Summary table | Generate Excel file with per-mandate summary sheets alongside OS Word doc | To Be (KI-003) |
| File type/size validation | Add logic to check file type and size (via content-type header) when file is uploaded to SharePoint via Power Automate | To Be — High priority (KI-004) |
| UAT/PROD Bitbucket pipelines | Add pipeline steps for UAT and PROD environments | Pending — no KI number assigned (dev doc T35 references old KI-006, now reassigned to App Insights) |
| Managed solution for flows | Move Power Automate Flows and PowerApps to managed solution | To Be (KI-007) |
| Improve error handling | Add criticality classification to Azure Function error handling | To Be (KI-008) |
| Credential cleanup | Remove settings.json and Appreg.txt (DEV credentials) from ospython repo | Pending — P1 security |
| Error Logs alerting | Power Automate flow to alert on new Critical Error Log entries | To Be |

---

## 16. NON-FUNCTIONAL REQUIREMENTS

| Requirement | Target |
|---|---|
| Resolution Dashboard initial load | ≤ 15 seconds |
| Add/Edit Resolution form load | ≤ 15 seconds |
| Azure Function — OS generation | ≤ 15 seconds |
| Azure Function — OP parsing | ≤ 15 seconds |
| Azure Function — RE generation | ≤ 20 seconds |
| Power Automate email ingestion | ≤ 5 minutes |
| SharePoint Online SLA | 99.9% |
| Azure Functions SLA (Consumption) | 99.95% |
| Max concurrent users | ~100 |
| Azure Functions concurrent executions | 200 (Consumption Plan default) |
| SharePoint list view threshold | 5,000 items — all queries must use indexed $filter |

---

## 17. DIAGRAMS (PlantUML files)

| Diagram | File | Description |
|---|---|---|
| C4 L1 — System Context | `uml/1.system-context-diagram.puml` | Actors and external systems |
| C4 L2 — Containers | `uml/2.container-diagram.puml` | Internal containers and interactions |
| C4 L3 — Deployment PROD As-Is | `uml/3.deployment-prod-diagram.puml` | PROD infrastructure topology |
| C4 L3 — Deployment PROD To-Be | `uml/4.deployment-prod-diagram-tobe.puml` | PROD target state (Managed Identity) |
| C4 L3 — Deployment DEV As-Is | `uml/5.deployment-dev-diagram.puml` | DEV environment topology |
| C4 L3 — Deployment DEV To-Be | `uml/6.deployment-dev-diagram-tobe.puml` | DEV target state |
| Resolution Workflow | `uml design/ResolutionWF.puml` | Email ingestion to OP extraction sequence |
| PBI Workflow | `uml design/PBIWF.puml` | PBI form submission and approval |
| OS Workflow | `uml design/OSWF.puml` | OS generation and multi-stage approval |
| RE Workflow | `uml design/RevEstReportWF.puml` | OP import and RE report generation |

---

## 18. DOCUMENTS

| File | Path | Description |
|---|---|---|
| MRMS Design Document | `Docs/1. MRMS_Design_Document.docx` | v1.0 (21/04/2026) — 11 sections, 39 tables; confirms Azure Key Vault for cert storage; 6 web parts listed; Azure Key Vault added as system component |
| Deployment & Configuration Guide | `Docs/2. MRMS_Deployment_Configuration_Guide.docx` | v1.1 (last modified 2026-04-21) — 13 sections, 28 tables; Section 2.3 extended with tech stack versions (SPFx 1.18.x, React 17.0.1, PnP ^3.20.1, FluentUI, TypeScript 4.7.4) + SharePoint Online + Power Automate; Section 7.4 Power Automate Licensing & BOM added; Section 7.1 Key Connections updated (HTTP added to premium flows); Section 7.3 updated with backup owner guidance and Word Online Business connector note |
| Maintenance & Operations Guide | `Docs/3. MRMS_Maintenance_Operations_Guide.docx` | v1.0 (21/04/2026) — 11 sections, 30 tables (inc. Appendix A Version History); Roles updated; KI table renumbered (KI-002 = OS Summary To-Be; KI-003 = file type/size check To-Be); certificate referenced as `mrms-cert.pfx` |
| Developer Code Documentation | `Docs/4. MRMS_Developer_Code_Documentation.docx` | v1.1 (23/04/2026) — fully populated; 415 paragraphs, 45 tables; 18 sections covering repo structure, tech stack, build pipeline, SPFx solutions, Azure Functions, services layer, security, CI/CD, known issues, ADRs; KI-005 (cert → Key Vault) and KI-006 (App Insights) marked COMPLETED |
| CostRates sample | `Docs/MRMSRates_2026_STAGE.xlsx` | 56 sheets, sample rates file |

---

## 19. PEOPLE & OWNERS

| Role | Person |
|---|---|
| Service Owner | Alexandros Hoc / Pritam Pawar |
| Site Administrator | Pritam Pawar / MRMS Service Account |
| Azure Functions Admin | Pritam Pawar |
| Configuration Manager | Alexandros Hoc |
| Flow Owner | MRMS Service Account (Stage/UAT/PROD) |
| Support / Dev team | Development team |

---

## 20. KNOWN ISSUES

| ID | Component | Severity | Symptom | Status |
|---|---|---|---|---|
| KI-001 | `generate_os_files` | Low | Generate OS fails with 'document is locked' if target .docx is open by another user | By design — lock detection intentional; no fix planned |
| KI-002 | ospython — auth | Resolved | Client secret auth replaced by Entra ID App Registration certificate-based MSAL | **RESOLVED** |
| KI-003 | `generate_os_files` | Medium | OS Summary Excel table (per-mandate summary) not yet implemented | To Be — scheduled for future release |
| KI-004 | Check file type/size | High | Add logic to check file type and size (content-type header) when file is uploaded to SharePoint via Power Automate | To Be |
| KI-005 | `ospython/Certificates/` | High | PFX certificate committed to source control | **COMPLETED** — certificate moved to Azure Key Vault |
| KI-006 | Azure Functions | Medium | Application Insights not connected to Function App | **COMPLETED** — Azure Application Insights connected |
| KI-007 | Power Automate / PowerApps | Medium | Flows and PowerApps not in a managed solution | To Be |
| KI-008 | Error Handling | Medium | Improve error handling to add criticality classification and better diagnostics | To Be |

---

## 21. GLOSSARY

| Term | Definition |
|---|---|
| MRMS | Mandate Review and Management System |
| SPFx | SharePoint Framework — Microsoft's model for client-side web parts |
| OP | Operative Paragraph — action paragraphs extracted from a resolution |
| OS | Oral Statement — generated Word document summarising mandate costs |
| PBI | Programme Budget Implication — cost estimate record linked to a mandate |
| RE Report | Revised Estimate Report — updated cost estimate document |
| CostRates | Excel workbook stored in SharePoint; system source of truth for all configuration |
| SafeList | SharePoint list of permitted sender email addresses for ingestion workflow |
| Document Set | SharePoint content type grouping related documents with shared metadata |
| UNOG | United Nations Office at Geneva |
| OICT | Office of Information and Communications Technology (UN) |
| PPBD | Programme Planning and Budget Division |
| FBO | Financial Budget Officer |
| ACABQ | Advisory Committee on Administrative and Budgetary Questions |
| OHCHR | Office of the UN High Commissioner for Human Rights |
| DGACM | Department for General Assembly and Conference Management |
| DCM | Division of Conference Management |
| DGC | Department of Global Communications |
| DSS | Department of Safety and Security |
| OLA | Office of Legal Affairs |
| CONFSERV | Conference Services — BudgetSectionName key for Section 2 |
| BudgetSectionID | Unique key e.g. `S.24_OHCHR` — primary identifier for PBI records |
| Entra ID | Microsoft cloud identity platform (formerly Azure Active Directory) |
| App-only Auth | Application authenticates to SharePoint using Entra ID App Registration with certificate (MSAL ConfidentialClientApplication); no client secrets used |
| Consumption Plan | Azure Functions hosting model — scales dynamically, billed per execution |
