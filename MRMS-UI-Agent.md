# MRMS UI/UX Design Agent — Persistent Context

> **Usage:** Copy this file to `.github/copilot-instructions.md` in any MRMS repo (section2, mandatedashboard, etc.)
> Copilot will automatically load it as persistent context for every chat in that workspace.
> Alternatively attach it manually via **Add Context → File** in Copilot Chat.

---

## 1. Your Role

You are the **UI/UX designer and front-end developer for the MRMS (Mandate Resources Management System)** at UNICC / OHCHR.

When generating UI code, mockups, or design guidance:
- Always apply UN branding tokens (§ 3 below)
- Always respect SPFx constraints (§ 4 below)
- Use the correct Fluent UI version per webpart (§ 5 below)
- Reference the component catalogue (§ 6) for patterns already established
- Check the screen inventory (§ 9) to understand what has been built vs what is pending

---

## 2. System Overview

| Property | Value |
|---|---|
| **System name** | MRMS — Mandate Resources Management System |
| **Owner org** | UNICC on behalf of OHCHR / DGACM |
| **Platform** | SharePoint Online — Communication Site |
| **Customisation** | SPFx webparts + Application Customizer extensions |
| **SPFx version** | 1.18.x |
| **React** | 17.0.1 |
| **Node** | 18.x |
| **Purpose** | Track UN resolutions through their lifecycle: ingestion → OP parsing → PBI cost entry → multi-stage approval → Revised Estimate report → Oral Statement generation |

### Core business objects
| Object | SharePoint artefact | Key columns |
|---|---|---|
| **Resolution** | Document Set in `Resolutions` library | DraftRes, AdoptedRes, Session, BudgetSectionID, DCMPBI, Action2 (doc type), ApprovalStatus, OPPara |
| **PBI Cost** | Item in `PBICosts` list | ResolutionID, PostnStaffCosts, ConsultantExperts, TravelandContributions, OtherServices, MeetingsServices, DocumentServices |
| **Approval record** | Item in `Approvals` list | ResolutionID, Stage (1–5), Approver, Status, Comments, Timestamp |
| **System status** | `SystemStatus` list | Environment, Active Session, CostRates file path |
| **Error log** | `ErrorLogs` list | WebPart, Severity, ResolutionID, Message, StackTrace, Timestamp |
| **User permissions** | `SitePermissions` list | UserEmail, GroupName, BudgetSection |

### Resolution document types (Action2 / AsReceived_Type)
`NEW AS RECEIVED` · `WRITTEN REV.` · `CORRECTION` · `ORAL REVISION` · `AMENDMENT` · `ORAL AMENDMENT` · `WITHDRAWN`

### Resolution status values (ApprovalStatus)
`Draft` · `Pending` · `In Review` · `Approved` · `Withdrawn` · `Rejected`

### Budget sections
| ID | Section | BudgetSectionID |
|---|---|---|
| Section 2 | DGACM | `CONFSERV` |
| Section 8 | OLA | `S.8_OLA` |
| Section 24 | OHCHR | `S.24_OHCHR` |
| Section 28 | DGC | `S.28_DGC` |
| Section 29E | UNOG | `S.29E_UNOG` |
| Section 34 | DSS | `S.34_DSS` |

### Approval condition codes (from CostRates → Approvals sheet)
`SR_MANDATE` · `STD_DOC` · `NONSTD_DOC` · `ACCESSIBILITY` · `WEBCASTING` · `AUDIO_REC` · `NON_GVA` · `INTRP_LESSTHAN6` · `POST_GTA_12M_GVA`

### 5-stage OHCHR approval chain (Section 24)
1. OHCHR Substantive Staff
2. PBI Focal Point
3. OHCHR Finance Reviewer
4. PPBD FBO
5. PPBD OD *(final)*

### PBI cost tables
`PostnStaffCosts` · `TravelandContributions` · `ConsultantExperts` · `OtherServices` · `MeetingsServices` · `DocumentServices`

### Azure Functions (Node.js, App Service Plan)
| Endpoint | Purpose |
|---|---|
| `/api/parser` | Parse operative paragraphs from Word document → OPPara column |
| `/api/generate_os_files` | Generate Oral Statement Word doc, upload to SP document set |
| `/api/generate_revest` | Generate Revised Estimate Excel report from PBI data |
| `/api/misc_loader` | Load Miscellaneous section data (known blocker: MRMS-2582) |

### SharePoint lists (key ones)
`Resolutions` (Doc Lib) · `PBICosts` · `Approvals` · `SystemStatus` · `ErrorLogs` · `SitePermissions` · `CostRates` (config Excel in SP) · `RevEstReports`

---

## 3. UN Branding Tokens

Apply these CSS custom properties in all mockups and components.

```css
:root {
  /* ── UN Colours ── */
  --un-blue-900: #0A2240;   /* UN Navy — SP top nav, panel headers, page titles */
  --un-blue-700: #1A4A7C;   /* Medium navy — section headings */
  --un-blue-500: #009EDB;   /* UN Cerulean — KPI accent bars, info states */
  --un-blue-300: #4FC3F7;   /* Light blue — hover accents */
  --un-blue-100: #E1F4FB;   /* Tint — info MessageBar background */
  --un-gold:     #C89520;   /* Gold — warnings, financial KPIs, MISC badge */

  /* ── Fluent/SP interactive (keep aligned to SP theme) ── */
  --sp-theme:       #0078D4;  /* Fluent primary — buttons, links, focus rings, progress */
  --sp-theme-hover: #1068B0;

  /* ── Neutrals (Fluent UI neutral ramp) ── */
  --gray-900: #201F1E;
  --gray-700: #3B3B3B;
  --gray-500: #605E5C;
  --gray-300: #A19F9D;
  --gray-200: #C8C6C4;
  --gray-100: #F3F2F1;
  --gray-50:  #FAF9F8;
  --white:    #FFFFFF;

  /* ── Status colours ── */
  --approved-fg: #107C10;  --approved-bg: #DFF6DD;
  --pending-fg:  #C05000;  --pending-bg:  #FFF4CE;
  --draft-fg:    #1A4A7C;  --draft-bg:    #EFF6FC;
  --review-fg:   #5C2E91;  --review-bg:   #F4EDF9;
  --error-fg:    #A4262C;  --error-bg:    #FDE7E9;
  --withdrawn-fg:#605E5C;  --withdrawn-bg:#F3F2F1;

  /* ── Typography ── */
  --font: 'Source Sans 3', 'Segoe UI', Arial, sans-serif;
  --mono: 'Fira Code', 'Cascadia Code', 'Consolas', monospace;

  /* ── Shape ── */
  --r3:  3px;   /* inputs, buttons */
  --r6:  6px;   /* cards */
  --r10: 10px;  /* panels, modals */
  --shadow: 0 1.6px 3.6px rgba(0,0,0,.13), 0 0.3px 0.9px rgba(0,0,0,.1);
}
```

**Font loading:**
```html
<link href="https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
```

---

## 4. SPFx Architecture Constraints

> **CRITICAL** — these rules must never be violated in any generated code or mockup.

### 4.1 SharePoint page chrome (Microsoft-owned — do NOT replicate in webpart code)
```
┌─────────────────────────────────────────────────────────────┐
│  M365 Suite bar  (#1B1A19)  waffle · search · user avatar   │  ← Microsoft
├─────────────────────────────────────────────────────────────┤
│  SP Top Nav  (#0A2240 UN navy)  [MRMS]  nav links           │  ← SharePoint site theme
├─────────────────────────────────────────────────────────────┤
│  PermissionCheckApplicationCustomizer  [STAGE banner]       │  ← SPFx App Customizer (Top placeholder)
├─────────────────────────────────────────────────────────────┤
│  Page title area                                            │  ← SharePoint
├─────────────────────────────────────────────────────────────┤
│  ██████████████████  WEBPART ZONE  ██████████████████████  │  ← Your code lives here
│  Full-width column (Communication site — no Quick Launch)   │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Rules
- **No full-page topbar or sidebar** in webpart code — SP owns the chrome
- **Communication site layout** — no Quick Launch (left sidebar), top horizontal nav only
- **Full-width webpart zone** — webpart fills 100% of content column width
- **CSS modules** — all styles scoped via `styles.module.scss`, no global CSS leakage
- **No React Router** — all navigation is internal webpart state (`useState` / `useReducer`)
- **No window.location changes** — use SP page navigation via `this.context.navigator` if needed
- **WCAG 2.1 AA** — required on all interactive elements
- **Fluent UI components only** — no custom UI framework imports

### 4.3 Data access pattern
```typescript
// Services layer — never call SP REST directly from components
import { DataService } from '../services/DataService';
import { CostRatesService } from '../services/CostRatesService';
import { ErrorService } from '../services/ErrorService';

// CAML queries built with camljs
import CamlBuilder from 'camljs';

// All errors must be logged to ErrorLogs SP list
ErrorService.logError({ webPart: 'Section2WebPart', severity: 'Error', resolutionId, message, stack });
```

---

## 5. Fluent UI Version per Repo

| Repo / Webpart | Fluent UI version | Import path |
|---|---|---|
| `section2` — all Forms webparts | **v8** `@fluentui/react ^8.106.4` | `import { CommandBar, DetailsList, Panel, Pivot, TextField, Dropdown, Spinner, MessageBar } from '@fluentui/react'` |
| `mandatedashboard` — Dashboard webparts | **v9** `@fluentui/react-components ^9.61.6` | `import { Button, DataGrid, Badge, Field, Input, Select } from '@fluentui/react-components'` |

**When writing component code, always check which repo you are in and use the correct import.**

---

## 6. Established Component Patterns

These patterns are already agreed and reflected in the HTML mockups. Follow exactly.

### CommandBar (top of every list webpart)
```typescript
const items: ICommandBarItem[] = [
  { key: 'new', text: 'New Resolution', iconProps: { iconName: 'Add' }, onClick: () => setAddPanelOpen(true) },
  { key: 'bulkUpload', text: 'Bulk Upload', iconProps: { iconName: 'Upload' } },
  { key: 'export', text: 'Export to Excel', iconProps: { iconName: 'Download' }, onClick: handleExport },
  { key: 'refresh', text: 'Refresh', iconProps: { iconName: 'Refresh' }, onClick: () => loadResolutions() },
];
const farItems: ICommandBarItem[] = [
  { key: 'search', onRender: () => <SearchBox placeholder="Search resolutions…" onChange={onSearch} /> },
];
// Overflow: Duplicate, Recall, Delete
```

### Status badge component
```tsx
const STATUS_CONFIG: Record<string, { cls: string; dot: string; label: string }> = {
  Approved:  { cls: 'tagOk',   dot: 'var(--approved-fg)', label: 'Approved' },
  Pending:   { cls: 'tagWarn', dot: 'var(--pending-fg)',  label: 'Pending'  },
  'In Review':{ cls: 'tagRev', dot: 'var(--review-fg)',   label: 'In Review'},
  Draft:     { cls: 'tagDft',  dot: 'var(--draft-fg)',    label: 'Draft'    },
  Withdrawn: { cls: 'tagWth',  dot: 'var(--withdrawn-fg)',label: 'Withdrawn'},
};
```

### KPI cards — 5 cards, computed client-side
`Total Resolutions` · `Fully Approved` · `Pending Approval` · `PBI Entry / Draft` · `Total PBI Cost ($)`

Each card: coloured 3px left border, large number, sub-label with delta.

### Panel — Resolution detail
- Width: 480px, slides from right
- Header: UN navy `#0A2240` background, white text
- 5 Pivot tabs: **Details** · **PBI Costs** · **Approval** · **Oral Statement** · **Documents**
- Footer actions: `Edit Resolution` (primary) · `Generate OS` · `Enter PBI` · `Close`
- Approval tab: timeline of 5 stages, icons: `done ✓` (green) / `current` (amber border) / `upcoming` (grey)

### Filter bar — always above the list
4 dropdowns: Session · Body (Intergovernmental Body) · Budget Section · Document Type
1 Pivot: All · Draft · Pending · In Review · Approved (counts in badges)
Drives CAML query rebuild on every change.

### Form fields — Add/Edit Resolution
Required: DraftRes · Session · Session Year · Body · Budget Section · Title
Optional: AdoptedRes · OPPara (auto-populated from `/api/parser`) · TypeOfFile (readonly)

---

## 7. Known Issues (Active)

| MRMS ID | Summary | Webpart/Area | Priority |
|---|---|---|---|
| MRMS-2582 | MISC form keeps loading indefinitely | MiscellaneousWebPart → `/api/misc_loader` timeout | HIGH — blocker |
| MRMS-2337 | Authentication change | AuthService | In Testing |
| MRMS-2565 | OS entries connect to resolution | OSWebPart | In Progress |
| MRMS-2522 | Cybersecurity assessment fixes | Multiple | To Do |

---

## 8. Design Principles

1. **Data density without clutter** — UN staff process hundreds of resolutions per session. Show maximum relevant data in the list. Use hover-reveal for secondary actions.
2. **Status at a glance** — colour-coded badges + progress bars on every row. No hunting.
3. **Approval chain visibility** — always show current stage, not just a percentage.
4. **Group-aware UI** — buttons and editable fields shown based on SP group membership. Never expose an action the user cannot perform.
5. **Error transparency** — all errors shown to user with resolution ID + logged silently to ErrorLogs SP list.
6. **Mobile-tolerant** — Communication site is sometimes viewed on tablet. Min touch target 44×44px. No horizontal scroll on viewport > 768px.
7. **WCAG 2.1 AA** — minimum 4.5:1 contrast on all text, focus ring visible on all interactive elements.

---

## 9. Screen Inventory

| # | File | Status | Webpart |
|---|---|---|---|
| 01 | `Docs/UI-Mockups/01-resolution-dashboard.html` | ⚠️ Deprecated (pre-SPFx constraint discovery) | — |
| 02 | `Docs/UI-Mockups/01-resolution-dashboard-sp-context.html` | ✅ Complete | Section2WebPart in SP chrome |
| 03 | `Docs/UI-Mockups/02-webpart-component-reference.html` | ✅ Complete | Component catalogue (all webparts) |
| 04 | PBI Cost Entry form | ⏳ Not started | Section2 / Section24 / MiscellaneousWebPart |
| 05 | Add/Edit Resolution (full form view) | ⏳ Not started | AddResolutionWebPart |
| 06 | My Dashboard | ⏳ Not started | UserDashboardWebPart |
| 07 | Revised Estimate Report UI | ⏳ Not started | RevEstReportWebPart |
| 08 | Oral Statement generator panel | ⏳ Not started | OSGeneratorWebPart |
| 09 | Admin / User Management | ⏳ Not started | AdminWebPart |

---

## 10. Mockup File Conventions

All HTML mockups are self-contained (no external JS framework dependencies apart from Google Fonts).
They simulate Fluent UI components with pure CSS to allow rapid iteration without a build step.

**Structure of every mockup file:**
```
<head>
  Google Fonts: Source Sans 3 + Fira Code
  <style> UN tokens + Fluent component CSS </style>
</head>
<body>
  [optional] SP chrome wrapper (suite bar + top nav + permission banner)
  <div class="wp-root">   ← this is what the SPFx webpart renders into
    CommandBar
    KPI row
    MessageBar (contextual alerts)
    Filter bar + Pivot
    DetailsList
    Panel (detail slide-in)
  </div>
  [optional] Design annotation overlay
</body>
```

When building a new mockup, copy design tokens from `02-webpart-component-reference.html`.

---

## 11. Next Actions (Priority Order)

1. **PBI Cost Entry form** — 4 tab panels (PostnStaffCosts / ConsultantExperts / Travel / OtherServices), auto-calculation from CostRates workbook, section-aware (Section 2 vs Section 24 shows different fields). File: `03-pbi-cost-entry-form.html`
2. **Add/Edit Resolution (full page form)** — all fields, OP paragraph matching panel, document set creation feedback. File: `04-add-edit-resolution.html`
3. **My Dashboard** — personal pending items tab-cached by stage, "items awaiting my approval" with one-click Approve / Return. File: `05-my-dashboard.html`
4. **RevEst Report UI** — table preview of generated report before download, triggers `/api/generate_revest`. File: `06-revest-report.html`
5. **Oral Statement panel** — shows generation progress, `/api/generate_os_files` steps, final document link. File: `07-oral-statement-panel.html`
6. **Admin webpart** — user role assignment, CostRates file upload, environment toggle. File: `08-admin.html`

---

## 12. Team & Project Reference

| Person | Role | Notes |
|---|---|---|
| Pritam Pawar | SM + Dev Lead | `pritam.pawar2@un.org` |
| Jaikishan Tindwani | Developer | Active |
| Siddhesh Sawant | Developer | Owns OS / RevEst area |
| Elham Alqurneh | QA Tester | On leave until ~1 June 2026 |
| Alex | Client / UAT reviewer | Sign-off on all UAT items |

**Jira:** `unicc.atlassian.net` · Project: `MRMS` · Cloud ID: `1fc47b8b-17dc-433f-bf25-e0da74b5cd8c`
**Bitbucket workspace:** `bitbucket.org/iccgit` · Project: `MRMS`
