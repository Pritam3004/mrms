# MRMS Power Automate Flows — Stage Environment Documentation

**Solution:** MRMS_Stage_1_0_0_3  
**Environment:** Stage  
**SharePoint Site:** `https://unitednations.sharepoint.com/sites/APP-STAGING-MRMS-MGT_DEV`  
**Shared Mailbox:** `mrms-staging@un.org`  
**Date Documented:** July 2025  

---

## Table of Contents

1. [Solution Overview](#1-solution-overview)
2. [Shared Infrastructure](#2-shared-infrastructure)
3. [Flow 1 — STAGING-MRMS-ResolutionWF](#3-flow-1--staging-mrms-resolutionwf)
4. [Flow 2 — STAGING-MRMSSystemStatusListUpdate](#4-flow-2--staging-mrmssystemstatuslistupdate)
5. [Flow 3 — STAGING-MRMS-ResolutionWF-BulkEmail](#5-flow-3--staging-mrms-resolutionwf-bulkemail)
6. [Flow 4 — STAGING-MRMS-ResolutionWF-BulkEmailChild](#6-flow-4--staging-mrms-resolutionwf-bulkemailchild)
7. [Flow 5 — STAGING-MRMSEmailnotificationworkflow](#7-flow-5--staging-mrmsemailnotificationworkflow)
8. [Flow 6 — STAGING-MRMSSendNewRESnotifications](#8-flow-6--staging-mrmssendnewresnotifications)
9. [Flow 7 — STAGING-UserPermissionWF](#9-flow-7--staging-userpermissionwf)
10. [Flow 8 — Stage-MRMS-ExporttoExcel](#10-flow-8--stage-mrms-exporttoexcel)
11. [Canvas App — User Management Tool](#11-canvas-app--user-management-tool)
12. [Flow Interaction Diagram](#12-flow-interaction-diagram)
13. [SharePoint Lists & Libraries Reference](#13-sharepoint-lists--libraries-reference)

---

## 1. Solution Overview

The MRMS (Mandate Reporting and Management System) Stage solution is a Power Platform solution that automates the end-to-end lifecycle of Human Rights Council draft resolutions at UNOG/OHCHR. It handles:

- **Ingestion of new and updated resolution documents** via a shared mailbox
- **Document storage** in SharePoint Document Sets
- **Status tracking** in a SharePoint Status list
- **Multi-group email notifications** driven by configurable templates
- **MMS approval workflows** with Power Automate Approvals
- **Bulk processing** of BE Amendments and Withdrawals
- **User permissions management** via a canvas app
- **CSV export** of user data

All flows run against the Stage SharePoint site. Premium Power Platform connectors are used (HTTP trigger, shared mailbox, approvals).

---

## 2. Shared Infrastructure

### Connections Used

| Connection Reference | Connector | Purpose |
|---|---|---|
| `shared_office365` | Office 365 Outlook | Send emails from `mrms-staging@un.org` |
| `shared_sharepointonline` | SharePoint Online | Read/write Resolutions, Status, EmailTemplatesHRC, UserManagement lists |
| `shared_sharepointonline_2` | SharePoint Online | Second reference (same site, some flows use two SP connection refs) |
| `shared_approvals` | Power Automate Approvals | Create and await MMS approval requests |
| `shared_approvals_1` | Power Automate Approvals | Second reference used in child flows |

### Key SharePoint Lists & Libraries

| Name | Type | Purpose |
|---|---|---|
| `Resolutions` | Document Library (Document Sets) | Stores all resolution drafts. Each Document Set = one draft resolution. |
| `Status` | List | Per-resolution per-group status tracking rows. Updated via CSOM (no version). |
| `EmailTemplatesHRC` | List | Configurable email templates. Key columns: `WFScenario`, `EmailType` (General / OHCHR / MMS), `Title` (subject template), `EN_Body` (body template). |
| `UserManagement` | List | User role assignments. Modified by canvas app. Triggers UserPermissionWF. |
| `UserEmails / SP Groups` | SP Group membership | Used at runtime to resolve group member email addresses. |

### Email Template Token Reference

Templates stored in `EmailTemplatesHRC` use the following placeholder tokens that are replaced at runtime:

| Token | Replaced With |
|---|---|
| `~sDraftResolution~` | DraftResolution identifier |
| `~sOldDraftResolution~` | Original DraftResolution (before revision/amendment) |
| `~bDraftResolution~` | DraftResolution (in email body) |
| `~bOldDraftResolution~` | Original DraftResolution (in email body) |
| `~bDraftResolutionTitle~` | ResolutionTitle |
| `~here~` | Hyperlink to Resolution edit form or Mandate-Dashboard |
| `~trainingpage1~` | Training page URL variable (amendment emails) |
| `~trainingpage2~` | Training page URL variable (amendment emails) |

### Status List System Update Pattern

Many flows update the `Status` list without creating a new version entry. This is achieved by calling SharePoint's CSOM endpoint directly:

```
POST _vti_bin/client.svc/ProcessQuery
Content-Type: text/xml;charset="UTF-8"
X-Requested-With: XMLHttpRequest
```

The CSOM XML body calls `SystemUpdate()` on the list item rather than `Update()`, bypassing version history and avoiding re-triggering any item-modified flows.

---

## 3. Flow 1 — STAGING-MRMS-ResolutionWF

**File:** `STAGING-MRMS-ResolutionWF-0B4D00FC-E642-F111-88B4-000D3ADDBF69.json`  
**Size:** 7,169 lines — the most complex flow in the solution  
**Premium:** Yes (shared mailbox trigger)

### Purpose

This is the **core resolution ingestion and processing flow**. It monitors the `mrms-staging@un.org` mailbox every minute and, when a qualifying email arrives, determines what kind of document action is required (new resolution, revision, correction, oral revision, amendment, oral amendment, or withdrawal), performs the corresponding SharePoint updates, uploads attachments, and sends notifications to the appropriate groups. It also submits an approval request to the MMS group after notifications are sent.

### Trigger

| Property | Value |
|---|---|
| Connector | `SharedMailboxOnNewEmailV2` (Office 365 Outlook) |
| Mailbox | `mrms-staging@un.org` |
| Poll interval | Every 1 minute |
| Include attachments | Yes |

**Subject filter conditions (ALL must pass):**

| Condition | Logic |
|---|---|
| Does not start with `re:` | Exclude email replies |
| Does not start with `fw:` | Exclude forwarded emails |
| Does not contain `be amendment` (spaces removed) | Routed to BulkEmail flow instead |
| Does not contain `be withdrawal` (spaces removed) | Routed to BulkEmail flow instead |
| Subject prefix (before first `:`) must be one of: `newasreceived`, `rev.`, `amendment`, `correction`, `oralrevision`, `withdrawn`, `oralamendment` | Case-insensitive, spaces removed |

**Email Subject Format:**

```
{ActionPrefix}: {Session} | {DraftResolution} | {ResolutionTitle}
```

Example:
```
New as received: HRC57 | A/HRC/57/L.1 | Right to development
Correction: HRC57 | A/HRC/57/L.1 | Right to development
Written Rev.: HRC57 | A/HRC/57/L.1/Rev.1 | Right to development
Amendment: HRC57 | A/HRC/57/L.2 | some title | to | A/HRC/57/L.1
```

### Connections

- `shared_office365` — send emails
- `shared_sharepointonline` — read Resolutions & Status list items (standard GetItems)
- `shared_sharepointonline_2` — HTTP REST calls for DocSet creation, MERGE updates, CSOM calls
- `shared_approvals` — create approval requests

### Variables Initialized

| Variable | Type | Initial Value | Purpose |
|---|---|---|---|
| `ResId` | string | — | SharePoint list item ID of the resolution |
| `currComments` | string | — | Current comments field content (read before appending) |
| `varAttach` | array | — | Attachment objects for email sending |
| `VarAttachEmail` | array | — | Attachment objects for email (same format) |
| `VarAttachApprove` | array | — | Attachment objects for approval requests |
| `Action2` | string | — | Normalized action type used for Switch and email template lookup |
| `DraftResolution` | string | — | The draft resolution identifier (e.g., `A/HRC/57/L.1`) |
| `OldDraftResolution` | string | — | Previous DraftResolution value before revision/amendment |
| `Action` | string | `trim(toUpper(split(subject,':')[0]))` | Raw action from subject prefix, uppercased |
| `Session` | string | — | Session number parsed from subject (e.g., `HRC57`) |
| `SessionYear` | string | `formatDateTime(utcNow(),'yyyy')` | Current year |
| `SessionMonth` | string | `formatDateTime(utcNow(),'MMMM')` | Current month name |
| `ResolutionTitle` | string | — | Resolution title parsed from subject |
| `Emaillink` | string | — | HTML hyperlink to Resolution edit page (internal link for OHCHR/MMS) |
| `GeneralEmaillink` | string | — | HTML hyperlink to Mandate-Dashboard (external link for General group) |
| `general subject` | string | — | Email subject for General group (token-replaced) |
| `general body mail` | string | — | Email body for General group (token-replaced) |
| `OHCHR subject` | string | — | Email subject for OHCHR groups (token-replaced) |
| `OHCHR body mail` | string | — | Email body for OHCHR groups (token-replaced) |
| `Approval subject line` | string | — | Approval request title for MMS group |
| `Approval body line` | string | — | Approval request body for MMS group |
| `CheckResID` | string | — | Used to check if a resolution already exists before creating |
| `CorrNumber` | integer | 0 | Sequential correction number |
| `OralRevNo` | integer | 0 | Sequential oral revision counter |
| `OralAmendNo` | integer | 0 | Sequential oral amendment counter |
| `AsReceived_Type` | string | — | Document type tag (e.g., `As Rec.`, `Corr.1`, `Oral Rev.1`) |
| `FileNameWithoutExtn` | string | — | Used during timestamp-insertion for oral revisions |
| `requestBody` | string | CSOM XML template | Pre-built CSOM XML for Status SystemUpdate. Token `${itemid}` is replaced per item. |
| `EmptyArray` | array | `[]` | Used to reset attachment arrays in Oral Revision / Oral Amendment cases |
| `MMSapprovername` | string | — | Display name + timestamp prefix used in Comments field update |
| `StatusID` | array | — | Used in WITHDRAWN case to collect Status item IDs for deletion |
| `varGeneralEmailGrp` | string | — | Semicolon-separated email addresses for General group |
| `varOHCHREmailgrp` | string | — | Semicolon-separated email addresses for OHCHR groups |
| `varMMSEmailGrp` | string | — | Semicolon-separated email addresses for MMS group (approvers) |

### High-Level Flow Sequence

```
Trigger (new email in mrms-staging@un.org)
  │
  ├─ Initialize ~25 variables
  │
  ├─ Determine Action (from subject prefix)
  │    ├─ Set Action2 = "NEW AS RECEIVED" if Action = "NEW AS RECEIVED"
  │    ├─ Set Action2 = "WRITTEN REV." if Action contains "REV."
  │    └─ Else: Action2 = Action
  │
  ├─ Check_if_subject_line_is_valid
  │    ├─ Parse Session, DraftResolution, ResolutionTitle, OldDraftResolution from subject
  │    └─ GET Resolutions ContentType ID (for DocSet creation)
  │
  ├─ Fetch EmailTemplatesHRC (WFScenario = Action2)
  │    └─ Filter into General / OHCHR / MMS sub-arrays
  │
  ├─ Resolve email group members
  │    └─ GET SP group users → build varGeneralEmailGrp / varOHCHREmailgrp / varMMSEmailGrp
  │
  ├─ Foreach_add_attachments_to_Variables
  │    └─ For each email attachment (skip .jpg/.png/.jpeg/.gif):
  │         append to varAttach, VarAttachEmail, VarAttachApprove
  │
  ├─ Switch on Action2
  │    ├─ NEW AS RECEIVED
  │    ├─ WRITTEN REV.
  │    ├─ CORRECTION
  │    ├─ ORAL REVISION
  │    ├─ AMENDMENT / ORAL AMENDMENT
  │    └─ WITHDRAWN
  │
  ├─ Scope__-_Operative_Para (post-switch)
  │
  └─ Send_Emails
       ├─ Send General email (always)
       ├─ Send OHCHR email (unless Action2 = CORRECTION in some paths)
       └─ Condition_10: if Action2 NOT "ORAL AMENDMENT"
            └─ Scope (Approval):
                 ├─ StartAndWaitForAnApproval (MMS group, 30-day timeout)
                 ├─ Switch Yes/No:
                 │    ├─ Yes: Update Resolution Comments with approver name + comment + DCMPBI=Yes
                 │    └─ No: Update Resolution Comments with "No DCM PBI" + DCMPBI=No
                 └─ (Post-approval: OHCHR & General emails also sent from within approval scope for WRITTEN REV.)
```

### Switch Branch Details

#### Case: NEW AS RECEIVED

This creates a brand-new Document Set in the Resolutions library.

1. **Duplicate check:** GET Resolutions filtered by `DraftResolution eq '{DraftResolution}'`
   - If found → `Terminate` (status: Failed, code: `401`, message: `"Resolution already exist"`)
2. **Create DocSet** via `POST _vti_bin/listdata.svc/Resolutions` with `Slug` header:
   ```
   Slug: {siteUrl}/Resolutions/{DraftResolution_underscored}|{ContentTypeId}
   ```
3. **Parse response** → extract new item `Id` → set `ResId`
4. **Upload attachments** to `/Resolutions/{DocSetName}/` (chunked transfer)
   - Per file: update file properties — `Title`, `ResolutionChanges = "-"`, `TypeofFile = "Received by Flow"`
5. **MERGE update DocSet metadata:**
   ```json
   { Session, DraftResolution, ResolutionTitle, ResolutionStatus:"Draft",
     SessionYear, SessionMonth, DSID, InterGovernmentalBody:"Human Rights Council" }
   ```
6. **Set email links:** `Emaillink` → Resolution edit form with `ResolutionID` param; `GeneralEmaillink` → Mandate-Dashboard with `rid` param
7. **Set AsReceived_Type** = `"As Rec."`
8. **Set email subject/body variables** using template tokens (NEW AS RECEIVED template path)
9. **(If Action = AMENDMENT):** Also set `OldDraftResolution` from subject parsing and use amendment email templates instead; update DocSet metadata with additional `ShortTitle` field

#### Case: WRITTEN REV.

1. **GET Resolutions** filtered by DraftResolution → parse `ResId`
2. **Check if name already contains "rev.":**
   - If YES → replace existing Rev portion: `split(currentName,'Rev')[0] + newRevSuffix`
   - If NO → append: `currentName + '/Rev.N'`
3. **MERGE update** DocSet: `DraftResolution` (new name), `ResolutionTitle`, `ResolutionStatus="Draft"`, `InterGovernmentalBody="Human Rights Council"`
4. **Check Status list** for existing items with this ResId → if found: loop-update each via CSOM `SystemUpdate` setting `Resolution` field to new DraftResolution name
5. **Upload attachments** to DocSet folder path (from `FieldValuesAsText/FileRef`)
   - Per file: update TypeofFile = "Received by Flow", ResolutionChanges = "Revision"
6. **Update Resolutions item** `ResolutionChanges = "Revision"` (via PatchFileItem)
7. **Set email links** and **set email subject/body** using WRITTEN REV. sub-path of MMS template
8. **Scope_2 (Approval):** `StartAndWaitForAnApproval` (MMS group, runs in parallel scope)
   - On completion: convert approval time to Romance Standard Time → set `MMSapprovername`
   - Switch Yes: update Resolution Comments with approver's comment
   - Switch No: update Resolution Comments with "No DCM PBI going forward..."
   - After approval: send OHCHR email + General email

#### Case: CORRECTION

1. **GET Resolutions** filtered by DraftResolution → parse `ResId`
2. **GET folder path** via `FieldValuesAsText/FileRef` → split after `/Resolutions/`
3. **Upload attachments** to `/Resolutions/{folder}/`
   - Per file: set `TypeofFile = "Received by Flow"`
4. **MERGE update** Resolution item: `ResolutionChanges = "Correction"`, `InterGovernmentalBody = "Human Rights Council"`
5. **GET Status list items** for ResId → loop CSOM `SystemUpdate` each (sets `RevisedorCorrected = 1`)
6. **Correction numbering:**
   - GET existing items WHERE `ResolutionID eq ResId AND AsReceived_Type contains 'Corr'` ORDER BY Modified desc
   - If found: read last `CorrectionNo`, increment by 1, set `AsReceived_Type = "Corr.{N}"`
   - If not found: `CorrNumber = 1`, `AsReceived_Type = "Corr."`
7. **Set Emaillink** (to Mandate-Dashboard with ResId)
8. **Set email subject/body** using CORRECTION templates (OHCHR + General)
9. Send General email only (OHCHR email skipped for CORRECTION in the main `Send_Emails` scope)
10. Approval sent to MMS via main `Condition_10` scope

#### Case: ORAL REVISION

1. **GET Resolutions** filtered by DraftResolution → parse `ResId`
2. **Get current time** → convert to Romance Standard Time format `yyyyMMdd_HHmm`
3. **GET DocSet folder path** via `FieldValuesAsText/FileRef`
4. **Reset** `varAttach` and `VarAttachApprove` to empty arrays
5. **Loop over email attachments directly** (different loop than global one — uses raw trigger attachments):
   - Skip .jpg/.png/.jpeg/.gif
   - Strip extension from filename → compose `{FileNameWithoutExtn}_{timestamp}{extension}`
   - Create timestamped file in DocSet folder
   - Update file properties: `TypeofFile = "Received by Flow"`, `ResolutionChanges = "-"`
   - Append to `varAttach` and `VarAttachApprove` with the new timestamped filename
6. **MERGE update** Resolution item: `ResolutionTitle`, `InterGovernmentalBody = "Human Rights Council"`
7. **Update file properties** on DocSet folder: `ResolutionChanges = "Oral Revision"`
8. **Get Status items** → CSOM `SystemUpdate` each
9. **Oral revision numbering:**
   - GET existing items WHERE `AsReceived_Type contains 'Oral R'` ORDER BY Modified desc
   - If found: read last `OralRevNo`, increment, set `AsReceived_Type = "Oral Rev.{N}"`
   - If not found: `AsReceived_Type = "Oral Rev."`, `OralRevNo = 1`
10. **Set email links and subject/body** using ORAL REVISION templates
11. Emails and approval sent via main `Send_Emails` scope

#### Case: AMENDMENT (and ORAL AMENDMENT)

The **Amendment** and **Oral Amendment** cases share the same `Case_NEW_or_AMENDMENT` Switch block as **NEW AS RECEIVED**, with the sub-path chosen by:

```
if (Action == "NEW AS RECEIVED") → New path
else → Amendment path
```

**Amendment path (within NEW_or_AMENDMENT case):**
1. DocSet is still created fresh (same creation API as New)
2. After creation and uploads, `OldDraftResolution` is parsed from subject: `split(subject,':')[1] → split('|')[2] → split('to')[1]` (the "to" resolution)
3. Email templates use `~sOldDraftResolution~` and `~bDraftResolution~` combined tokens
4. Amendment email body includes `~trainingpage1~` and `~trainingpage2~` tokens (OHCHR emails)

**Oral Amendment:**  
Follows the same timestamp-file-naming logic as Oral Revision. Uses `OralAmendNo` counter. `AsReceived_Type = "Oral Amend.{N}"`. Approval is **skipped** (controlled by `Condition_10`: if Action2 = "ORAL AMENDMENT" → skip approval scope).

#### Case: WITHDRAWN

1. **GET Resolutions** filtered by DraftResolution → parse `ResId`
2. **MERGE update** Resolution: `ResolutionStatus = "Withdrawn by sponsor(s)"`
3. **GET Status list items** for this ResId
4. **If items exist:** loop collect `StatusId`, then DELETE each via `DELETE _api/web/lists/GetByTitle('Status')/items({id})` (Status rows removed when resolution is withdrawn)
5. **Set GeneralEmaillink** (Mandate-Dashboard link)
6. **Set general subject/body** from WITHDRAWN email template
7. Send General email only (no OHCHR, no approval for withdrawals)

### Post-Switch: Approval Logic (Send_Emails Scope)

For all action types (except ORAL AMENDMENT and CORRECTION which have own paths):

1. **Send General email** from `mrms-staging@un.org` to `varGeneralEmailGrp` with `varAttach` attachments
2. **Condition_9:** If Action2 ≠ "CORRECTION" → also send OHCHR email to `varOHCHREmailgrp`
3. **Condition_10:** If Action2 ≠ "ORAL AMENDMENT" → enter approval scope:
   - `StartAndWaitForAnApproval` (CustomResponse: Yes / No): sent to `varMMSEmailGrp`, 30-day timeout, includes attachments, links to Resolution edit form
   - On completion: Convert time to Romance Standard Time (`dd/MM/yyyy HH:mm`)
   - Build `MMSapprovername` prefix: `"{DisplayName} ({date}): {ActionType}: "`
     - Prefix format varies by Action2 (Written Revision, Oral Rev., Correction, etc.)
   - **Switch on outcome:**
     - **Yes:** For each approver response with a comment: update Resolution `Comments` field — prepend `"{MMSapprovername}{comment} || "` to existing comments; if Action = NEW/AMENDMENT also set `DCMPBI = "Yes"`
     - **No:** Update Resolution `Comments` with `"No DCM PBI"` or `"No DCM PBI going forward..."` text; set `DCMPBI = "No"`

### Error Handling

- New resolution duplicate → explicit `Terminate` (Failed, code 401)
- All attachment loops are inside the main flow with no explicit try/catch except for the WRITTEN REV. approval scope (which uses `Scope_2`)
- `Set_variable_Approval_body` failure in WRITTEN REV. scope → triggers fallback `Scope_2` path

---

## 4. Flow 2 — STAGING-MRMSSystemStatusListUpdate

**File:** `STAGING-MRMSSystemStatusListUpdate-94191A02-E742-F111-88B4-000D3ADDBF69.json`  
**Size:** ~100 lines  
**Premium:** Yes (HTTP trigger)

### Purpose

A simple utility flow that accepts a pre-built CSOM XML payload and submits it to SharePoint's `_vti_bin/client.svc/ProcessQuery` endpoint. This allows SPFx web parts and other flows to update Status list items silently (without creating a new version or triggering other flows) by constructing the CSOM payload externally and POSTing it here.

### Trigger

| Property | Value |
|---|---|
| Type | HTTP POST (manual trigger) |
| Body schema | `{ "Requestbody": string }` |

### Logic

```
1. Initialize Body variable = triggerBody()?['Requestbody']

2. POST to SharePoint:
   URL:  _vti_bin/client.svc/ProcessQuery
   Headers:
     Content-Type: text/xml;charset="UTF-8"
     X-Requested-With: XMLHttpRequest
     Accept: */*
   Body: @{variables('Body')}
```

### Called By

- SPFx web parts (via HTTP action buttons on forms)
- Potentially other flows that need to update Status without triggering versioning

### Data Interactions

| List | Operation |
|---|---|
| Status | CSOM SystemUpdate (no version created) — exact fields depend on caller's XML payload |

---

## 5. Flow 3 — STAGING-MRMS-ResolutionWF-BulkEmail

**File:** `STAGING-MRMS-ResolutionWF-BulkEmail-084D00FC-E642-F111-88B4-000D3ADDBF69.json`  
**Size:** 2,567 lines  
**Premium:** Yes (shared mailbox trigger)

### Purpose

Handles **bulk amendment and withdrawal** email notifications. This flow runs on the same mailbox but listens specifically for emails with subject prefixes `BE AMENDMENT:` or `BE WITHDRAWAL:`. Unlike ResolutionWF which processes one resolution per email, BulkEmail is designed for batch operations — a single email may reference multiple resolutions. The flow parses a list of resolution names from the email body, looks up each one, and dispatches notifications. For MMS approval routing, it calls the `BulkEmailChild` flow as a child.

### Trigger

| Property | Value |
|---|---|
| Connector | `SharedMailboxOnNewEmailV2` |
| Mailbox | `mrms-staging@un.org` |
| Poll interval | Every 1 minute |

**Subject filter conditions:**

| Condition | Logic |
|---|---|
| NOT contains `re:` | Exclude replies |
| NOT contains `fw:` | Exclude forwards |
| Subject (spaces removed, lowercased) MUST contain `beamendment:` OR `bewithdrawal:` | Only BE operations |

**Email Subject Format:**
```
{BE Amendment | BE Withdrawal}: {Session} | {Resolutions pipe-separated} | {Title}
```

### Variables Initialized

| Variable | Type | Purpose |
|---|---|---|
| `ResId` | string | Current resolution SP item ID |
| `currComments` | string | Existing comments before append |
| `varAttach` | array | Email attachments |
| `VarAttachEmail` | array | Email attachments (email format) |
| `VarAttachApprove` | array | Approval attachments |
| `Action` | string | `trim(toUpper(split(subject,':')[0]))` |
| `Action2` | string | Same as Action (BE ops) |
| `DraftResolution` | string | Current resolution being processed in the loop |
| `OldDraftResolution` | string | Original resolution reference |
| `Group-DCM-IS` | string | DCM IS group email string |
| `IsResolutionConfirmed` | boolean | Tracks per-resolution confirmation state |
| `Session` | string | Session number `HRC57` etc. |
| `ResolutionTitle` | string | Title of resolution |
| `DraftResArr` | array | Array of draft resolution names parsed from email body |
| `IncomingResolutionName` | string | Current item being iterated in bulk loop |
| `CheckResID` | string | Duplicate check variable |
| `StatusID` | array | Collected Status item IDs |
| `FileNameWithoutExtn` | string | Filename manipulation |

### Logic

```
1. Initialize variables

2. Condition: Action = "BE AMENDMENT" or "BE WITHDRAWAL"
   ├─ Parse Session, ResolutionTitle from subject
   └─ GET Resolutions ContentTypeId

3. Process attachments (same image-exclusion logic as ResolutionWF)

4. Parse email body → extract list of resolution names
   └─ Each resolution is on its own line, comma-separated, or pipe-separated
      (exact parsing via split/trim on email body)

5. For each DraftResolution in the list:
   ├─ GET Resolutions item by DraftResolution name → set ResId
   ├─ GET EmailTemplatesHRC WHERE WFScenario = Action2
   ├─ Filter templates into General / OHCHR / MMS arrays
   ├─ Set Emaillink / GeneralEmaillink
   ├─ Set email subject/body variables (token replacement)
   │
   ├─ For "BE AMENDMENT":
   │    ├─ MERGE update Resolution: set ResolutionChanges = "BE Amendment"  
   │    ├─ Upload attachments to DocSet folder
   │    ├─ Send General email
   │    ├─ Send OHCHR email
   │    └─ Call BulkEmailChild (HTTP POST) with headers:
   │         DraftResolution: {current resolution}
   │         OriginalResolution: {original resolution from subject}
   │         Action: MMS
   │
   └─ For "BE WITHDRAWAL":
        ├─ MERGE update Resolution: ResolutionStatus = "Withdrawn by sponsor(s)"
        ├─ DELETE Status list items for this ResId (same pattern as WITHDRAWN in ResolutionWF)
        ├─ Send General email
        └─ Send OHCHR email
```

### Data Interactions

| List / Library | Operations |
|---|---|
| Resolutions | GET (by DraftResolution), MERGE update (ResolutionChanges, ResolutionStatus) |
| Status | GET (for ResId), DELETE items (on withdrawal) |
| EmailTemplatesHRC | GET (by WFScenario) |
| SharePoint Groups | GET users (to build email groups) |

### Calls

- **STAGING-MRMS-ResolutionWF-BulkEmailChild** (HTTP POST) — for MMS approval routing on BE Amendments

---

## 6. Flow 4 — STAGING-MRMS-ResolutionWF-BulkEmailChild

**File:** `STAGING-MRMS-ResolutionWF-BulkEmailChild-094D00FC-E642-F111-88B4-000D3ADDBF69.json`  
**Size:** 1,583 lines  
**Premium:** Yes (HTTP trigger)

### Purpose

A **child flow** called by BulkEmail to handle MMS approval routing for BE Amendment operations. It receives the amendment resolution details via HTTP headers (not body), resolves MMS group membership, sends the approval request, and follows up with notification emails and a dashboard link.

### Trigger

| Property | Value |
|---|---|
| Type | HTTP POST (manual trigger) |
| Body schema | None — reads from HTTP request headers |
| Headers consumed | `DraftResolution`, `OriginalResolution`, `Action` |

### Variables Initialized

| Variable | Type | Initial Value | Purpose |
|---|---|---|---|
| `DraftResolution` | string | — | From header |
| `OriginalDraftRes` | string | — | From header |
| `ResId` | string | — | SP list item ID |
| `ResolutionTitle` | string | — | Resolution title |
| `UsersCol` | array | — | User objects collected from SP group |
| `SPGroupUsers` | string | — | Semicolon-separated email list |
| `varAttachment` | array | — | Attachments for approval |
| `varAmendment` | string | — | Formatted amendment string for email body |
| `dashboardlink` | string | `{siteUrl}/SitePages/Mandate-Dashboard.aspx` | Pre-set link |
| `ShortendResolution` | string | — | Shortened display version of resolution list |
| `EmptyArray` | array | `[]` | Reset variable |
| `MMSapprovername` | string | — | Approver display name + timestamp |

### Logic

```
1. Initialize variables

2. Scope_Emails:
   └─ Switch on Action header:
        └─ Case "MMS":
             ├─ Set DraftResolution from header
             ├─ GET MMS SP group users (GetByName)
             ├─ Loop users → build SPGroupUsers (semicolon list of emails)
             └─ Send approval via shared_approvals_1:
                  Title: "BE Amendment: {DraftResolution}"
                  AssignedTo: {SPGroupUsers}
                  Details: email body template
                  ItemLink: Resolution edit page with ResolutionID param
                  Attachments: varAttachment

3. GET ResId from Resolutions list by DraftResolution

4. Compose ShortendResolution:
   └─ Multiline bullet list of resolutions for email body

5. Build varAmendment string:
   └─ "{OriginalDraftRes} → {DraftResolution}"

6. Send email notification to MMS group:
   └─ Subject: amendment reference
   └─ Body: includes dashboardlink and varAmendment string
   └─ Attachments: varAttachment
```

### Called By

- STAGING-MRMS-ResolutionWF-BulkEmail (HTTP POST)

---

## 7. Flow 5 — STAGING-MRMSEmailnotificationworkflow

**File:** `STAGING-MRMSEmailnotificationworkflow-96191A02-E742-F111-88B4-000D3ADDBF69.json`  
**Size:** 1,221 lines  
**Premium:** Yes (HTTP trigger)

### Purpose

A **reusable generic notification child flow** called from SPFx web parts and other flows. It accepts a rich JSON body describing the notification context, looks up the appropriate email template from `EmailTemplatesHRC`, resolves the email addresses of the target SharePoint groups at runtime, and sends personalized emails to each group member.

### Trigger

| Property | Value |
|---|---|
| Type | HTTP POST (manual trigger) |
| Body schema | Full JSON object |

**Input Body Schema:**

| Field | Type | Description |
|---|---|---|
| `DraftResolution` | string | Resolution identifier |
| `DraftResolutionTitle` | string | Resolution title |
| `FormLink` | string | URL to the form/page for context |
| `EmailType` | string | Template type filter (e.g., `General`, `OHCHR`, `MMS`) |
| `FormName` | string | Name of the calling form |
| `SendTo` | string | Semicolon-separated SP group names |
| `Action` | string | Action context string |
| `CurrentUser` | string | Display name of the user triggering the notification |
| `UserEmail` | string | Email of the current user (for individual notifications) |
| `MandateCategory` | string | Mandate categorization |
| `DateTimestamp` | string | ISO timestamp |
| `Comments` | string | Optional comments from caller |
| `BulkUpdate` | boolean | True if this is a bulk operation |
| `FileName` | string | Relevant file name |
| `SessionNumber` | string | Session reference |
| `SiteUrl` | string | Site URL |
| `ReviewerType` | string | Type of reviewer |
| `BudgetSection` | string | Budget section reference |

### Variables

| Variable | Type | Purpose |
|---|---|---|
| `SPGroupUsers` | string | Runtime-resolved semicolon list of user emails |
| `varEmailPropCol` | object | Stores all trigger body fields as a single object for easy token access |
| `varCommentWithLine` | string | Comments with separator appended |
| `varAttachments` | array | Attachments if any |

### Logic

```
1. Initialize varEmailPropCol with all trigger body fields

2. Try scope:
   ├─ GET EmailTemplatesHRC WHERE WFScenario = varEmailPropCol.EmailType
   ├─ Parse template result
   │
   └─ Loop_and_get_groups: For each group in SendTo (split by ';'):
        ├─ Condition: group name not empty
        ├─ GET _api/web/sitegroups/getbyname('{groupName}')/users
        ├─ Parse user list
        └─ For each user in group:
             ├─ Replace template tokens in subject and body
             └─ Send email via shared_office365 to user's email address

3. Also handles direct UserEmail send (for individual notifications bypassing group lookup)
```

### Token Replacement in Templates

The flow uses the `varEmailPropCol` object to replace tokens in templates. All input fields are available as replacement values including:
- `DraftResolution`, `DraftResolutionTitle`, `FormLink`, `Action`, `CurrentUser`, `Comments`, `DateTimestamp`, `SessionNumber`, `BudgetSection`, etc.

### Called By

- SPFx web part approval buttons (via HTTP action)
- Potentially other flows requiring configurable email delivery

---

## 8. Flow 6 — STAGING-MRMSSendNewRESnotifications

**File:** `STAGING-MRMSSendNewRESnotifications-95191A02-E742-F111-88B4-000D3ADDBF69.json`  
**Size:** 1,312 lines  
**Premium:** Yes (HTTP trigger)

### Purpose

Sends **new resolution creation notifications** to all configured recipient groups. This flow is called by ResolutionWF immediately after a new resolution Document Set is created (NEW AS RECEIVED path). It reads the `CreateNotify` email templates and dispatches notifications to each configured group.

### Trigger

| Property | Value |
|---|---|
| Type | HTTP POST (manual trigger) |
| Body | `{ "DraftResolution": string, "ResolutionTitle": string }` |

### Variables

| Variable | Type | Purpose |
|---|---|---|
| `ResId` | string | SP item ID of the new resolution |
| `currcomments` | string | Existing comments (rarely used in this flow) |

### Logic

```
1. Initialize variables

2. GET Resolutions WHERE DraftResolution eq '{DraftResolution}'
   └─ Parse ResId

3. GET EmailTemplatesHRC WHERE WFScenario = 'CreateNotify'
   └─ Parse template items

4. Loop_and_get_groups: For each template row:
   └─ Switch on EmailType:
        ├─ Case "General":
        │    For each group in Send_To (split by ';'):
        │      ├─ Condition: group not empty
        │      ├─ GET SP group users by name
        │      └─ For each user:
        │           ├─ Replace tokens: ~bDraftResolution~, ~bDraftResolutionTitle~, ~here~
        │           └─ Send email from mrms-staging@un.org
        │
        ├─ Case "OHCHR":
        │    Same pattern → different template row → OHCHR groups
        │
        └─ Case "MMS":
             Same pattern → different template row → MMS groups
```

The `~here~` token in CreateNotify templates links to:
```
{siteUrl}/SitePages/Mandate-Dashboard.aspx?rid={ResId}
```

### Called By

- STAGING-MRMS-ResolutionWF (after new resolution DocSet created successfully)

---

## 9. Flow 7 — STAGING-UserPermissionWF

**File:** `STAGING-UserPermissionWF-BF191A02-E742-F111-88B4-000D3ADDBF69.json`  
**Size:** 585 lines  
**Premium:** No (SharePoint trigger, SP connector only)

### Purpose

Synchronizes a user's **SharePoint group membership** whenever the UserManagement list is created or modified by the canvas app. Implements a clean-slate role reassignment: removes the user from all current groups, then adds them to the correct groups based on the new role assignment stored in the list item.

### Trigger

| Property | Value |
|---|---|
| Connector | SharePoint Online — item created or modified |
| List GUID | `7c4c1888-fc2a-4d4e-99a5-0e0a9a73f18f` (UserManagement list) |
| Poll interval | Every 1 minute |

The trigger fires any time a row is created or updated in UserManagement. The canvas app writes/updates a row here when a Focal Point changes a user's role.

### Variables

| Variable | Type | Purpose |
|---|---|---|
| `VarUserID` | string | SharePoint internal user ID (integer as string) |

**Trigger item fields consumed:**
- `UNEmail` — the user's UN email address
- Role assignment columns (read during the Add step)

### Logic — Step by Step

```
1. Try scope:

2. Check_if_user_is_present:
   └─ POST _api/web/SiteGroups/GetByName('DCM EO STAGING-MRMS-MGT Visitors')/Users
      Body: { LoginName: "i:0#.f|membership|{UNEmail}" }
      Purpose: Ensures user is in the SP user database (resolves/creates user entry)
   └─ Parse response → extract UserId → set VarUserID

3. Get_UserGroups:
   └─ GET /_api/web/GetUserById({VarUserID})/Groups
   └─ Parse all current group memberships

4. Apply_to_each_for_Removing_User_from_Groups:
   └─ For EACH group the user currently belongs to:
        └─ POST _api/Web/SiteGroups({groupId})/Users/RemoveByID({VarUserID})
        Purpose: Clean slate — user removed from ALL groups
        Note: Even Visitors group is removed (re-added later)

5. Apply_to_each_for_Adding_User_to_Groups:
   └─ Read role assignments from trigger item
   └─ For each assigned SP group in the item:
        └─ POST _api/web/SiteGroups/GetByName('{groupName}')/Users
           Body: { LoginName: "i:0#.f|membership|{UNEmail}" }

6. Add_User_to_Visitor_Group (final step):
   └─ Always re-add to 'DCM EO STAGING-MRMS-MGT Visitors'
      Purpose: Ensures base read access is always preserved
```

### Why This Pattern?

Rather than computing the diff between old and new roles, the flow uses a simpler and more reliable "remove all → add correct" approach. This avoids edge cases where a user might have been manually added/removed from groups through other means. The final Visitors re-add ensures no user loses basic site read access.

### Data Interactions

| Resource | Operation |
|---|---|
| UserManagement list | READ trigger item (role columns, UNEmail) |
| SP Users | POST to add user to site user store |
| SP Groups (all current) | GET user's groups, then POST RemoveByID for each |
| SP Groups (assigned) | POST to add user to new groups |
| Visitors group | POST add (always, as final step) |

### Called By

- Canvas App (MRMS User Management Tool) — writes/updates UserManagement list row

---

## 10. Flow 8 — Stage-MRMS-ExporttoExcel

**File:** `Stage-MRMS-ExporttoExcel-97191A02-E742-F111-88B4-000D3ADDBF69.json`  
**Size:** Small (~200 lines)  
**Premium:** Yes (PowerApps V2 trigger, SharePoint invoker connection)

### Purpose

Exports the **current user list** (as shown in the User Management canvas app) to a timestamped CSV file in SharePoint. Called when the user presses the Export button in the canvas app. Returns the download URL of the generated file to the app.

### Trigger

| Property | Value |
|---|---|
| Type | PowerApps V2 |
| Inputs | `JsonInput` (text — JSON array of user records), `SiteUrl` (text) |
| Connection mode | Invoker (runs under the calling user's identity) |

**`JsonInput` JSON Schema (per user object):**

| Field | Type |
|---|---|
| `Title` | string (FirstName) |
| `LastName` | string |
| `UNEmail` | string |
| `Entity` | `{ Value: string }` |
| `Division` | `{ Value: string }` |
| `Branch` | `{ Value: string }` |
| `Section` | `{ Value: string }` |
| `Groups` | `[{ Id: number, Value: string }]` |
| `Unit` | `{ Value: string }` |
| `Location` | `{ Value: string }` |

### Logic — Step by Step

```
1. Compose SiteUrl from trigger input

2. Parse JSON:
   └─ Parse JsonInput string as array of user objects

3. Select (flatten/map each record):
   └─ For each user:
        Map Groups array to comma-separated string using XPath:
          xpath(
            xml(json(concat('{ "root": {"Labels":', string(item()?['Groups']), '}}')))
            , '//Value/text()'
          )
        Map Entity/Division/Branch/Section/Unit/Location: item()?['FieldName']?['Value']
        Produce flat object: FirstName, LastName, UNEmail, Entity, Division, Branch, Section, Unit, Location, Groups (comma-separated)

4. Create_CSV_table:
   └─ Convert flattened array to CSV with column headers

5. Create_file:
   └─ Path: /Export Data/export_{yyyyMMddhhmmss}.csv
   └─ Body: UTF-8 BOM prefix (%EF%BB%BF) + CSV content
   └─ This ensures correct encoding when opened in Excel

6. Compose full URL:
   └─ {SiteUrl} + file path from create_file response

7. Respond_to_a_PowerApp_or_flow:
   └─ Return: { "linkoutput": "{full_download_url}" }
```

### Called By

- MRMS User Management Tool canvas app (Export button)

### Data Interactions

| Resource | Operation |
|---|---|
| SharePoint `/Export Data/` library | CREATE file (`export_{timestamp}.csv`) |

---

## 11. Canvas App — User Management Tool

**Name:** `stg_stagemrmsusermanagementtool_ca99a`  
**Files:** `.msapp` bundle, background image, identity JSON

### Purpose

A model-driven-style canvas application that allows MRMS Focal Points to:
- Search and view all users in the system
- Assign roles to users (writes to UserManagement list → triggers UserPermissionWF)
- Export the filtered user list to CSV (calls ExporttoExcel flow)

### Integration Points

| Action | Mechanism |
|---|---|
| Role assignment | Write/update UserManagement list row → triggers UserPermissionWF |
| Export user list | Call ExporttoExcel flow → receive back CSV download URL → open in browser |
| Read user data | PowerApps data connector to SP UserManagement list |

---

## 12. Flow Interaction Diagram

```
Email arrives at mrms-staging@un.org
        │
        ├──[beamendment/bewithdrawal in subject]──────────► BulkEmail (Flow 3)
        │                                                          │
        │                                                          │ HTTP POST (MMS approval)
        │                                                          ▼
        │                                              BulkEmailChild (Flow 4)
        │
        └──[other prefixes]───────────────────────────► ResolutionWF (Flow 1)
                                                                   │
                              ┌────────────────────────────────────┘
                              │ (after new DocSet created)
                              ▼
                   SendNewRESnotifications (Flow 6)


SPFx Web Part (approval buttons)
        │
        │ HTTP POST (notification requests)
        ▼
EmailNotificationWorkflow (Flow 5)

SPFx Web Part (status updates)
        │
        │ HTTP POST (CSOM XML)
        ▼
SystemStatusListUpdate (Flow 2)


Canvas App (User Management Tool)
        │
        ├──[role change → writes UserManagement list]──► UserPermissionWF (Flow 7)
        │
        └──[export button]─────────────────────────────► ExporttoExcel (Flow 8)
                                                                   │
                                                                   │ Returns CSV URL
                                                                   ▼
                                                          Browser download
```

---

## 13. SharePoint Lists & Libraries Reference

### Resolutions (Document Library)

**Type:** Document Library with Document Sets  
**Content Type:** `Resolution_DS`  
**Key Columns:**

| Column | Type | Notes |
|---|---|---|
| `DraftResolution` | text | Primary identifier (e.g., `A/HRC/57/L.1`) |
| `ResolutionTitle` | text | Title of the resolution |
| `ResolutionStatus` | choice | `Draft`, `Withdrawn by sponsor(s)`, etc. |
| `ResolutionChanges` | choice | `Correction`, `Revision`, `Oral Revision`, `Oral Amendment`, `BE Amendment`, `-` |
| `InterGovernmentalBody` | text | Always `Human Rights Council` |
| `Session` | text | Session reference (e.g., `HRC57`) |
| `SessionYear` | text | 4-digit year |
| `SessionMonth` | text | Month name |
| `DSID` | number | Document Set item ID (self-referential) |
| `ShortTitle` | text | Short version of title |
| `Comments` | text | MMS approver comments (format: `{name} ({date}): {action}: {comment} \|\| {prev}`) |
| `DCMPBI` | choice | `Yes` / `No` — whether DCM PBI is proceeding |
| `TypeofFile` | choice | `Received by Flow` for auto-uploaded files |

### Status (List)

**Key Columns:**

| Column | Type | Notes |
|---|---|---|
| `ResolutionID` | number | Foreign key to Resolutions list item ID |
| `Resolution` | text | DraftResolution name copy |
| `RevisedorCorrected` | boolean | Set to 1 via CSOM when revision/correction arrives |

### EmailTemplatesHRC (List)

**Key Columns:**

| Column | Type | Notes |
|---|---|---|
| `WFScenario` | text | Action type key (e.g., `NEW AS RECEIVED`, `CORRECTION`, `CreateNotify`) |
| `EmailType` | text | Audience: `General`, `OHCHR`, `MMS` |
| `Title` | text | Email subject template (contains token placeholders) |
| `EN_Body` | text | Email body template (HTML, contains token placeholders) |
| `Send_To` | text | Semicolon-separated SharePoint group names to send to |

### UserManagement (List)

**List GUID:** `7c4c1888-fc2a-4d4e-99a5-0e0a9a73f18f`  
**Key Columns:**

| Column | Type | Notes |
|---|---|---|
| `UNEmail` | text | User's UN email (login identity) |
| `UserId` | lookup/text | SP user ID |
| Role assignment columns | text/choice | Group names to assign |

### Key SharePoint Groups (Stage)

| Group Name | Purpose |
|---|---|
| `DCM EO STAGING-MRMS-MGT Visitors` | Base read-access group — all users are always members |
| `DCM EO STAGING-MRMS-MGT Members` | Standard members |
| `DCM EO STAGING-MRMS-MGT Owners` | Site owners |
| MMS group (resolved from EmailTemplatesHRC) | Receives approval requests |
| General groups (resolved at runtime from templates) | Receive informational email notifications |
| OHCHR groups (resolved at runtime from templates) | OHCHR Secretariat groups receiving resolution notifications |

---

*End of document*
