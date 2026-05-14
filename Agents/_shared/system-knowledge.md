# MRMS — System Knowledge Reference

> **Full technical knowledge base:** `MRMS_System_Knowledge_Base.md` (root of workspace)
> Read it when you need architecture, code structure, SharePoint lists, Azure Functions, or CostRates details.

---

## Quick Identity

- **Full name:** Mandate Review and Management System (MRMS)
- **Organisation:** UNOG / UNICC
- **Tenant:** `unitednations.sharepoint.com` (Tenant ID: `0f9e35db-544f-4f60-bdcc-5ea416e6dc70`)
- **Platform:** SharePoint Online (SPFx) + Power Automate + Azure Functions (Python 3.11) + Power BI + Azure Key Vault
- **Purpose:** Full lifecycle management of intergovernmental meeting resolutions — ingestion → OP parsing → PBI cost entry → approval → OS generation → RE reporting

## Environments

| Env | URL |
|---|---|
| DEV (Stage) | `https://unitednations.sharepoint.com/sites/APP-STAGING-MRMS-MGT_DEV` |
| UAT | `https://unitednations.sharepoint.com/sites/UAT-MRMS-MGT` |
| PROD | `https://unitednations.sharepoint.com/sites/mrms-mgt` |

## Repositories (Bitbucket — workspace: `iccgit`)

| Repo | Local | Purpose |
|---|---|---|
| `section2` | `C:\Repos\MRMS\section2` | SPFx — Resolution forms, PBI entry (MRMS-Forms, SPFx 1.18.x / FluentUI v8) |
| `mandatedashboard` | `C:\Repos\MRMS\mandatedashboard` | SPFx — Dashboards, RE Report, Permission check (MRMS-Dashboards, FluentUI v9) |
| `ospython` | `C:\Repos\MRMS\ospython` | Azure Functions Python 3.11 — OS gen, OP parser, RE gen |

## Key Technology

- SPFx 1.18.x · React 17 · PnP JS ^3.20.1 · FluentUI v8 (forms) / v9 (dashboards)
- Azure Functions v2 (Python 3.11) · MSAL certificate-based auth (no client secrets)
- Power Automate (2 premium flows: HTTP connector/trigger)
- CostRates Excel workbook (56 sheets) — system source of truth for all config

## People

| Person | Role |
|---|---|
| Pritam Pawar | SM + Dev Lead (`pritam.pawar2@un.org`) |
| Jaikishan TINDWANI | Developer |
| Siddhesh SAWANT | Developer (owns OS/RevEst area) |
| Alex | Client / UAT reviewer |
| Elham ALQURNEH | QA Tester (on leave until ~June 1, 2026) |
