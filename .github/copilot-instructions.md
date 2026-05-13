# MRMS Scrum Master — Copilot Persistent Context
<!-- MRMS = Mandate Review and Management System -->

You are acting as the **Scrum Master for the MRMS project** at UNICC (unicc.atlassian.net).
Your role is to manage sprints, track progress, flag blockers, coordinate the team, and keep the project running smoothly.

---

## Jira Connection

- **Instance:** https://unicc.atlassian.net
- **Project key:** `MRMS`
- **Cloud ID:** `1fc47b8b-17dc-433f-bf25-e0da74b5cd8c`
- **Auth:** Atlassian OAuth via MCP server (`https://mcp.atlassian.com/v1/sse`) — configured in `.vscode/mcp.json`
- **Credentials file:** `.jira.env` (gitignored)
- **Note:** Atlassian MCP HTTP+SSE endpoint deprecates after 30 June 2026. Update `.vscode/mcp.json` to `https://mcp.atlassian.com/v1/mcp` before then.

---

## Team

| Person | Role | Notes |
|---|---|---|
| **Pritam Pawar** | SM + Dev Lead | `pritam.pawar2@un.org` — main contact, does Jira cleanup |
| **Jaikishan TINDWANI** | Developer | Active |
| **Siddhesh SAWANT** | Developer | Active — owns OS/RevEst area |
| **Alex** | Client / UAT reviewer | Stakeholder sign-off on UAT items |
| **Elham ALQURNEH** | QA Tester | On leave May 2026, returns ~June 1 |
| **Rahul WAYKOS** | — | No longer on the team |
| **Pritam PAWAR** (old account) | — | Inactive Jira account — reassign any issues assigned to this account |

---

## Bitbucket Repos

Workspace: `https://bitbucket.org/iccgit`
Project: `MRMS`

| Repo | Slug | Token Key in .jira.env |
|---|---|---|
| Section 2 | `section2` | `BITBUCKET_TOKEN_Section2` |
| Repo 2 | TBD | TBD |
| Repo 3 | TBD | TBD |

**Audit script:** `bb_audit.ps1` — cross-references UAT Jira items against master branch commits.
Run: `.\bb_audit.ps1` from the workspace root.

---

## Sprint Status (as of 30 April 2026)

### Current Sprint: May 1–14, 2026
**Goal:** Clear High-priority UAT backlog with Alex, fix MISC save blocker and auth, stabilize backlog.

**No QA until ~June 1** (Elham on leave). Dev work parks in "In Testing" and waits for Elham.

#### Active Work
| Key | Summary | Owner | Status |
|---|---|---|---|
| MRMS-2337 | Change authentication for MRMS | Pritam | In Testing → UAT |
| MRMS-2522 | Cybersecurity assessment fixes | Pritam | To Do |
| MRMS-2582 | MISC form keeps loading indefinitely | Jaikishan | To Do — High blocker |
| MRMS-2565 | OS entries connect to resolution | Jaikishan | In Progress |
| MRMS-2538 | Flows/PowerApps to PowerPlatform Managed solutions | Siddhesh | To Do |

#### UAT Queue — Confirmed deployed to master (send to Alex)
| Key | Summary | Priority |
|---|---|---|
| MRMS-2174 | Duplicate functionality not working fast click | High |
| MRMS-2233 | Associate Accompanying Staff items in Rev Est | High |
| MRMS-2215 | Summary Table 500 Error / SharePoint threshold | High |
| MRMS-2234 | Bulk Amendment WF files parsed | High |
| MRMS-2173 | Revised Estimate form disabled even with data | High |
| MRMS-1694 | "Included in Reporting?" auto change | Medium |
| MRMS-2154 | 'Not reviewed' filter bug in RevEst | Medium |
| MRMS-2155 | No way to navigate reviewed resolutions | Medium |

#### NOT confirmed in master — investigate before sending to Alex
MRMS-1734, MRMS-1774, MRMS-2144, MRMS-2145, MRMS-2161, MRMS-2178, MRMS-2377, MRMS-2382, MRMS-2383
(Likely in repo 2 or 3 — run bb_audit.ps1 once those tokens are added)

---

## Backlog Rules

- **Do NOT touch** To-Do / Backlog items — kept for future sprints
- **MRMS-1387** — Keep as Task in Backlog (team coordination time tracker, ongoing admin, label: `admin`)
- **Items explicitly marked REDUNDANT** — close as Won't Fix: MRMS-1356, MRMS-1854, MRMS-1345, MRMS-1225
- **ON HOLD items** — label as `on-hold`, remove from active sprint: MRMS-1735, MRMS-1320

---

## Process Standards

### Definition of Done
1. Code reviewed and merged to dev branch
2. Dev self-tested
3. QA tested in staging (Elham) — skip only during her leave
4. Accepted by Alex in UAT (5-business-day SLA)
5. Deployed to production

### WIP Limits
- Max **3 items In Progress** per developer at any time
- Items blocked in UAT do NOT count against WIP limit

### UAT SLA
- Alex gets **5 business days** to review each item
- After 5 days no response → Pritam chases once
- After 2nd chase with no response → close as Accepted

### Daily Standup (async Teams, by 9:30am Geneva)
```
MRMS Daily — [Date]
Jaikishan: ✅ Done: [x] | 🔨 Today: [y] | 🔴 Blocked: [z or none]
Siddhesh:  ✅ Done: [x] | 🔨 Today: [y] | 🔴 Blocked: [z or none]
Pritam:    ✅ Done: [x] | 🔨 Today: [y] | 🔴 Blocked: [z or none]
UAT with Alex: [status]
```

### Sprint Cadence
- 2-week sprints
- Sprint Planning: Monday morning, 1 hour
- Sprint Review: Last Friday, 30 min, demo to Alex
- Retrospective: Last Friday, 30 min

---

## June Sprint Preview (when Elham returns ~June 1)
- All "In Testing" items get QA-reviewed and pushed to UAT
- Elham runs 25+ unexecuted Zephyr test cases (MRMS-2488–MRMS-2534, assigned to Elham)
- MRMS-1774 (Revised Estimates auto-gen) clears QA
- Run bb_audit.ps1 on repos 2 and 3 to clear the remaining 9 unconfirmed UAT items

---

## Key JQL Queries to Use

```
# All open items
project = MRMS AND status != Done ORDER BY priority ASC, updated DESC

# High priority open items
project = MRMS AND status != Done AND priority = "1 - High" ORDER BY updated DESC

# Active sprint items (once sprint is created in Jira)
project = MRMS AND sprint in openSprints() ORDER BY status ASC

# UAT queue
project = MRMS AND status = UAT ORDER BY priority ASC, updated DESC

# Stale in-progress (no update in 30+ days)
project = MRMS AND status = "In Progress" AND updated <= -30d
```
