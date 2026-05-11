# MRMS: Bitbucket + Jira → GitHub Migration Plan

**Project:** MRMS  
**Team Size:** 4 Developers  
**Solutions:** 3 SPFx Solutions  
**Current Stack:** Atlassian Bitbucket + Jira  
**Target Stack:** GitHub Repositories + GitHub Actions + GitHub Projects  
**Date:** April 2026  

---

## Overview

The MRMS project consists of 3 SPFx solutions hosted on Atlassian Bitbucket with related tasks tracked in Jira. Each solution follows a branch-per-task strategy that merges through `dev → stage → uat → prod` branches, with automated pipelines deploying `.sppkg` packages to SharePoint site collection app catalogs.

This document outlines the full migration plan, including pros and cons, step-by-step instructions, effort estimates, and risk mitigations — prepared for team and management review.

---

## Pros & Cons

### Moving to GitHub — Pros

- **Single platform** — Code, tasks, CI/CD pipelines, wikis, and documentation all live in one place, eliminating context switching between Bitbucket and Jira
- **GitHub Issues + Projects** provides native task tracking integrated directly with pull requests and commits
- **GitHub Actions** replaces Bitbucket Pipelines with a richer ecosystem, more marketplace actions, and better SPFx/SharePoint deployment support
- **Superior pull request experience** — inline suggestions, required reviewers, draft PRs, and auto-merge options
- **GitHub Copilot** integrates natively — directly beneficial to the dev team's productivity
- **Better free tier** — more generous private repo and Actions minutes allowances
- **Wider hiring pool** — most developers are already familiar with GitHub workflows
- **GitHub Environments** provide built-in approval gates for UAT and PROD deployments, replacing any manual gates in Bitbucket Pipelines
- **GitHub Packages** available if MRMS ever publishes shared SPFx libraries or npm packages internally

### Moving to GitHub — Cons

- **Jira is more powerful for project management** — GitHub Projects lacks advanced features like epics, sprints with burndown charts, velocity tracking, and detailed reporting; this is a meaningful downgrade if management relies on those reports
- **Pipeline rewrite required** — `bitbucket-pipelines.yml` does not translate directly to GitHub Actions; all workflows must be rewritten
- **Branch protection rules** must be reconfigured from scratch on GitHub
- **Secrets and credentials** (Azure AD app registrations, SharePoint URLs) must be re-entered into GitHub Secrets per repository and per environment
- **Webhooks and external integrations** (e.g., Slack/Teams notifications, SharePoint app catalog deploy hooks) must be re-pointed to GitHub
- **Team onboarding time** — even experienced developers need time to adjust to GitHub Actions syntax and GitHub Projects workflow
- **Cross-team Jira dependency** — if other teams or business units outside MRMS use the same Jira instance, migrating MRMS tasks alone may fragment project tracking across the organization

---

## Migration Strategy Recommendation

> **Migrate one solution at a time — not all three simultaneously.**

Migrate Solution 1 fully (repository + pipelines + issues), validate it through one complete sprint cycle, then proceed with Solutions 2 and 3. This approach reduces risk significantly for an active 4-person development team and provides learning opportunities before tackling all solutions.

---

## Migration Steps

---

### Phase 1 — Preparation & Audit

**Timeline:** Week 1  
**Effort:** 1–2 days  
**Who:** Lead Developer  

**1.1 — Audit all 3 Bitbucket repositories**
- List all branches across each solution and classify them as: active task branch, environment branch (`dev`/`stage`/`uat`/`prod`), or stale/obsolete
- Clean up stale branches before migration to avoid carrying unnecessary history
- Document the current `bitbucket-pipelines.yml` for each solution:
  - What triggers each pipeline (push, tag, manual)
  - What environments it deploys to
  - What credentials/variables it uses
  - Which SharePoint site collection app catalog each environment targets

**1.2 — Audit Jira**
- Export all open issues and current sprint items to CSV from Jira (use Jira's built-in export: *Board → Backlog → Export Issues*)
- Keep this CSV as a permanent archive record regardless of what gets migrated
- Decide migration scope: **recommended approach** is to only migrate currently open/active items; close historical items in Jira and archive them
- Map Jira fields to GitHub equivalents:

| Jira | GitHub |
|---|---|
| Issue Type (Bug, Story, Task) | Issue Labels |
| Priority | Issue Labels |
| Sprint | Milestone |
| Epic | GitHub Project custom field or Label |
| Assignee | GitHub Assignee |
| Status columns | GitHub Project board columns |
| Components | Labels or separate repos |

**1.3 — Create GitHub Organization**
- Create a GitHub Organization (e.g., `your-company` or `your-company-mrms`)
- Add all 4 developers and assign roles:
  - Lead Developer: **Owner**
  - Other Developers: **Member**
- Enforce organization-level settings:
  - Require Two-Factor Authentication (2FA) for all members
  - Configure SSO if your company uses Azure AD / Entra ID (recommended for enterprise)

**1.4 — Plan repository structure**
- Create 3 repositories matching the current 3 Bitbucket repos (keep naming consistent)
- Do **not** consolidate into a monorepo unless there is a specific business reason — separate repos preserve current workflow and pipeline isolation

---

### Phase 2 — Repository Migration

**Timeline:** Week 1–2  
**Effort:** 1 day  
**Who:** Lead Developer  

**2.1 — Mirror each repository to GitHub**

The mirror approach preserves full git history, all branches, and all tags. Run the following in **PowerShell** or **Git Bash for Windows** for each of the 3 solutions:

```powershell
# Step 1: Clone the Bitbucket repo as a bare mirror
git clone --mirror https://bitbucket.org/your-org/solution-name.git

# Step 2: Navigate into the cloned mirror folder
cd solution-name.git

# Step 3: Update the remote URL to point to GitHub
git remote set-url origin https://github.com/your-org/solution-name.git

# Step 4: Push everything — all branches, tags, and history
git push --mirror
```

> Repeat these 4 steps for each of the 3 solutions.

**2.2 — Verify the migration for each repo**
- Confirm all environment branches exist: `dev`, `stage`, `uat`, `prod`
- Confirm task/feature branches are present
- Confirm full commit history is intact (check earliest commits)
- Confirm all tags are present

**2.3 — Configure branch protection rules** on GitHub for each repo

Navigate to: `Repository → Settings → Branches → Add branch protection rule`

| Branch | Protection Rules |
|---|---|
| `prod` | Require PR, require 2 reviews, require status checks, restrict direct push |
| `uat` | Require PR, require 1 review, require status checks |
| `stage` | Require PR, require 1 review |
| `dev` | Require PR, require 1 review |

---

### Phase 3 — Pipeline Migration (Bitbucket Pipelines → GitHub Actions)

**Timeline:** Week 2  
**Effort:** 2–3 days  
**Who:** 1–2 Developers  

This is the most technically complex phase. Each solution's `bitbucket-pipelines.yml` must be translated into GitHub Actions workflow files.

**3.1 — Create the workflows folder structure** in each solution repository:

```
.github/
  workflows/
    ci.yml                  # Runs on every Pull Request — build and test only
    deploy-dev.yml          # Triggers on push/merge to dev branch
    deploy-stage.yml        # Triggers on push/merge to stage branch
    deploy-uat.yml          # Triggers on push/merge to uat branch
    deploy-prod.yml         # Triggers on push/merge to prod branch (with approval gate)
```

**3.2 — Example: PR Validation Workflow (`ci.yml`)**

```yaml
name: CI - Build and Validate

on:
  pull_request:
    branches: [dev, stage, uat, prod]

jobs:
  build:
    runs-on: ubuntu-latest        # Ubuntu is recommended for Node.js/SPFx CI builds
                                  # even when developers are on Windows workstations —
                                  # the runner is the CI server, not the dev machine
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Bundle SPFx solution
        run: gulp bundle --ship

      - name: Package SPFx solution
        run: gulp package-solution --ship
```

**3.3 — Example: Deploy to DEV App Catalog (`deploy-dev.yml`)**

```yaml
name: Deploy to DEV App Catalog

on:
  push:
    branches: [dev]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: dev              # Links to GitHub Environment for secrets and approval gates

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Bundle SPFx solution
        run: gulp bundle --ship

      - name: Package SPFx solution
        run: gulp package-solution --ship

      - name: Deploy to SharePoint Site Collection App Catalog
        uses: pnp/action-cli-deploy@v3
        with:
          APP_FILE_PATH: sharepoint/solution/*.sppkg
          SITE_COLLECTION_URL: ${{ secrets.SITE_COLLECTION_URL }}
          TENANT_ID: ${{ secrets.TENANT_ID }}
          CLIENT_ID: ${{ secrets.CLIENT_ID }}
          CLIENT_SECRET: ${{ secrets.CLIENT_SECRET }}
          SKIP_FEATURE_DEPLOYMENT: true
          OVERWRITE: true
```

> Replicate this pattern for `deploy-stage.yml`, `deploy-uat.yml`, and `deploy-prod.yml`,
> changing the `environment:` field and `branches:` trigger accordingly.

**3.4 — Configure GitHub Environments**

Navigate to: `Repository → Settings → Environments`

Create the following environments and configure secrets per environment:

| Environment | Secrets Needed | Approval Gate |
|---|---|---|
| `dev` | `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SITE_COLLECTION_URL` | None |
| `stage` | Same set, stage-specific values | None |
| `uat` | Same set, UAT-specific values | Required reviewer (e.g., Lead Dev) |
| `prod` | Same set, PROD-specific values | Required reviewer (e.g., Manager + Lead Dev) |

> Using GitHub Environments is the recommended approach over repository-level secrets
> because it scopes credentials per environment and enforces approval gates natively.

**3.5 — Azure AD App Registration for SharePoint Deployment**
- Ensure an Azure AD (Entra ID) App Registration exists with the following API permissions:
  - `Sites.FullControl.All` (SharePoint)
  - Or use certificate-based authentication if your organization requires it
- Add the Client ID, Client Secret, and Tenant ID as environment secrets in step 3.4
- If no such app registration exists, request one from your Azure admin during Phase 1

---

### Phase 4 — Jira → GitHub Projects Migration

**Timeline:** Week 2–3  
**Effort:** 1–2 days  
**Who:** Lead Developer or Project Manager  

**4.1 — Create a GitHub Project**
- Navigate to: GitHub Organization → Projects → New Project
- Choose **Board** layout (equivalent to Jira Kanban/Scrum board)
- Name it: `MRMS Project Board`
- Define columns: `Backlog | In Progress | In Review | QA/Testing | Done`
- Add custom fields:
  - **Priority**: Single select — Critical, High, Medium, Low
  - **Solution**: Single select — Solution 1, Solution 2, Solution 3
  - **Sprint**: Iteration field
  - **Environment**: Single select — DEV, STAGE, UAT, PROD

**4.2 — Create GitHub Issue Labels** (across all 3 repos)

```
Type:     bug, feature, task, improvement, documentation
Priority: priority-critical, priority-high, priority-medium, priority-low
Solution: solution-1, solution-2, solution-3
Env:      env-dev, env-stage, env-uat, env-prod
```

**4.3 — Migrate open Jira issues**

Options — choose one based on backlog size:

| Option | Best For | Tool |
|---|---|---|
| Manual creation | Small backlog (< 50 items) | GitHub UI |
| CSV import via script | Medium backlog (50–200 items) | GitHub CLI or node-jira-to-github |
| Dedicated migration tool | Large backlog | GitHub Marketplace apps |

For a 4-person team, **manual migration of current sprint items** combined with a CSV archive of the full backlog is the most pragmatic approach.

**4.4 — Create issue and PR templates**

Add these files to each repository:

```
.github/
  ISSUE_TEMPLATE/
    bug_report.md
    feature_request.md
    task.md
  PULL_REQUEST_TEMPLATE.md
```

**Sample PR Template (`.github/PULL_REQUEST_TEMPLATE.md`):**

```markdown
## Summary
Brief description of the changes.

## Related Issue
Closes #(issue number)

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Pipeline / Infrastructure change

## Solution Affected
- [ ] Solution 1
- [ ] Solution 2
- [ ] Solution 3

## Testing
Steps to verify this change works as expected.

## Deployment Notes
Any special steps required when deploying this to each environment.

## Checklist
- [ ] Code builds without errors (`gulp bundle --ship`)
- [ ] Package created successfully (`gulp package-solution --ship`)
- [ ] Tested in DEV environment
- [ ] No console errors in browser
```

---

### Phase 5 — Team Onboarding & Cutover

**Timeline:** Week 3  
**Effort:** 1 day  
**Who:** All 4 Developers  

**5.1 — Team training session (1–2 hours)**

Cover the following topics:
- GitHub flow vs current Bitbucket flow (they are very similar — the mental model is the same)
- How to link PRs to issues using keywords: `Closes #123`, `Fixes #123`
- How to read and debug GitHub Actions pipeline logs
- GitHub Projects board usage — moving issues and linking to PRs
- How required reviewers and environment approval gates work

**5.2 — Update local git remotes** on each developer's Windows machine

Run in **PowerShell** or **Git Bash** from inside each solution folder:

```powershell
# Verify current remote
git remote -v

# Update to GitHub URL
git remote set-url origin https://github.com/your-org/solution-name.git

# Verify the change
git remote -v

# Fetch all branches from new remote
git fetch --all
```

> Each of the 4 developers must run this for all 3 solution repositories on their local machine.

**5.3 — Set Bitbucket repos to read-only / archived**
- Go to each Bitbucket repo → Repository Settings → Archive Repository
- Do **not** delete yet — keep for a minimum 30-day reference period
- Communicate clearly to the team: *"Bitbucket is now read-only. All new work goes to GitHub."*

**5.4 — Update external integrations**
- Update Slack / Microsoft Teams notifications that point to Bitbucket — replace with GitHub webhooks or GitHub's native Slack/Teams app
- Update status badges in README files or SharePoint pages
- Update any links in company wikis or SharePoint documentation pages

---

### Phase 6 — Validation & Stabilization

**Timeline:** Week 3–4 (ongoing monitoring)  
**Effort:** 1–2 weeks of parallel observation  
**Who:** All Developers  

**6.1 — Run one complete deployment cycle per solution**
- Complete a full pipeline run: PR → merge to `dev` → `stage` → `uat` → `prod`
- Verify `.sppkg` deploys correctly to each SharePoint site collection app catalog
- Verify the app upgrades properly in each environment

**6.2 — Monitor for two full sprints**
- Keep Bitbucket archived but accessible as a read-only fallback reference
- Track any pipeline failures or permission issues and resolve before decommissioning

**6.3 — Decommission Bitbucket and Jira**
- After 30 days of successful operations on GitHub, formally close Bitbucket and Jira subscriptions
- Ensure the Jira CSV export is stored in a secure, accessible location (e.g., SharePoint document library) for historical reference

---

## Effort Estimate Summary

| Phase | Description | Who | Estimated Effort |
|---|---|---|---|
| 1 | Preparation & Audit | Lead Dev | 1–2 days |
| 2 | Repository Migration (3 repos) | Lead Dev | 1 day |
| 3 | Pipeline Rewrite (3 solutions × 5 workflows) | 1–2 Devs | 2–3 days |
| 4 | Jira → GitHub Projects | Lead Dev / PM | 1–2 days |
| 5 | Team Onboarding & Cutover | All 4 Devs | 1 day |
| 6 | Validation & Stabilization | All | 1–2 weeks monitoring |
| **Total Active Effort** | | | **~8–10 working days** |
| **Total Calendar Time** | | | **3–4 weeks** |

> **Note:** Active effort and calendar time differ because Phase 6 runs in parallel with normal sprint
> work. The team is not blocked for 3–4 weeks — active migration work is concentrated in Phases 1–5.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Pipeline secrets misconfigured causing failed deployments | Medium | High | Test DEV environment pipeline end-to-end before touching UAT/PROD pipelines |
| Branch history or tags lost during mirror | Low | High | Use `git clone --mirror`, verify all branches and tags before decommissioning Bitbucket |
| SPFx app catalog deploy authentication breaks on GitHub Actions | Medium | High | Pre-validate Azure AD App Registration permissions against site collection app catalog before cutover |
| Team unfamiliarity with GitHub Actions YAML | Low | Medium | Keep Bitbucket Pipelines YAML files as reference; GitHub Actions syntax is similar |
| Open Jira tickets lost | Low | Medium | Export all issues to CSV before migration as permanent archive |
| Other teams using same Jira instance impacted | Low | Low | Confirm MRMS has its own Jira project scope — only MRMS tickets need to move |
| Manager reporting gap (Jira burndown / velocity reports missing) | Medium | Medium | Discuss with management whether GitHub Projects reporting meets needs before committing to full Jira retirement |

---

## Decision Points for Management

The following items require a management decision before migration begins:

1. **GitHub Organization tier** — Free, Team ($4/user/month), or Enterprise? For 4 developers with private repos and required reviewers, **GitHub Team** is recommended.

2. **Jira migration scope** — Migrate only open/active issues (recommended) or attempt to migrate full Jira history?

3. **Jira retirement timeline** — When to stop paying for Jira/Bitbucket subscriptions. Recommend: 30 days after successful GitHub cutover.

4. **Azure AD App Registration** — Does an app registration with SharePoint `Sites.FullControl.All` permission already exist for CI/CD? If not, this requires Azure admin involvement and should be requested in Phase 1.

5. **SSO / Entra ID integration** — Does the organization require GitHub access to be managed through Azure AD Single Sign-On? This requires GitHub Enterprise and Azure AD admin cooperation.

---

## Summary

The migration from Bitbucket/Jira to GitHub is a well-scoped, low-risk project for a team of 4 developers with 3 SPFx solutions. The primary technical effort is rewriting the deployment pipelines as GitHub Actions workflows. Repository migration preserves full git history and is straightforward. Task migration is pragmatic — only active items need to move; historical items are archived as CSV.

**Recommended start:** Begin with Phase 1 (audit) immediately, targeting a full cutover within 4 weeks while keeping Bitbucket and Jira active as fallback until validation is complete.
