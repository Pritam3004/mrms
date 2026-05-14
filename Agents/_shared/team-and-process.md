# MRMS — Team & Process Reference

## Team

| Person | Role | Notes |
|---|---|---|
| **Pritam Pawar** | SM + Dev Lead | `pritam.pawar2@un.org` — main contact |
| **Jaikishan TINDWANI** | Developer | Active |
| **Siddhesh SAWANT** | Developer | Active — owns OS/RevEst area |
| **Alex** | Client / UAT reviewer | Stakeholder sign-off on UAT items — 5-business-day SLA |
| **Elham ALQURNEH** | QA Tester | On leave May 2026, returns ~June 1 |

**No longer on team:** Rahul WAYKOS. Inactive Jira account: "Pritam PAWAR" (old) — reassign any issues to active account.

---

## Jira

- **Instance:** https://unicc.atlassian.net · **Project:** `MRMS` · **Cloud ID:** `1fc47b8b-17dc-433f-bf25-e0da74b5cd8c`
- **Auth:** Atlassian MCP (`https://mcp.atlassian.com/v1/sse`) — configured in `.vscode/mcp.json`
- **Note:** SSE endpoint deprecates 30 June 2026 → migrate to `https://mcp.atlassian.com/v1/mcp`

### Key JQL

```jql
-- All open
project = MRMS AND status != Done ORDER BY priority ASC, updated DESC

-- High priority
project = MRMS AND status != Done AND priority = "1 - High" ORDER BY updated DESC

-- Active sprint
project = MRMS AND sprint in openSprints() ORDER BY status ASC

-- UAT queue
project = MRMS AND status = UAT ORDER BY priority ASC, updated DESC

-- Stale in-progress
project = MRMS AND status = "In Progress" AND updated <= -30d
```

---

## Process Standards

### Definition of Done
1. Code reviewed and merged to dev branch
2. Dev self-tested
3. QA tested in staging (Elham) — skip only during her leave
4. Accepted by Alex in UAT (5-business-day SLA)
5. Deployed to production

### WIP Limits
- Max **3 items In Progress** per developer
- Items blocked in UAT do NOT count against WIP limit

### UAT SLA
- 5 business days → no response → Pritam chases once
- 2nd chase, no response → close as Accepted

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
- Sprint Review: Last Friday, 30 min (demo to Alex)
- Retrospective: Last Friday, 30 min

---

## Backlog Rules

- **Do NOT touch** To-Do/Backlog items — future sprints only
- **MRMS-1387** — keep as Task (admin time tracker, label: `admin`)
- **Redundant — close Won't Fix:** MRMS-1356, MRMS-1854, MRMS-1345, MRMS-1225
- **On Hold — label `on-hold`, remove from sprint:** MRMS-1735, MRMS-1320
