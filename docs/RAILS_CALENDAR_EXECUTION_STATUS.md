# Rails Calendar — execution status / single entrypoint for next chat

**As-of:** 2026-11-21; **type:** date-stamped checkpoint, not realtime.  
**Live source:** GitHub [PR #81](https://github.com/TheGor-365/rails_calendar/pull/81), latest **HEAD SHA + code + exact-SHA CI**. Every new assistant MUST fetch fresh SHA and refresh this file.  
**Companion docs:** [NEXT_CHAT_MASTER](RAILS_CALENDAR_NEXT_CHAT_MASTER.md) · [MVP_EXECUTION_ROADMAP](RAILS_CALENDAR_MVP_EXECUTION_ROADMAP.md).  
**Status notation:** `CODE` = in feature branch; `CI` = exact prior SHA passed; `UI` = manual acceptance; `DB` = local migration; `PROD` = authorized deployment. **A green CI is not UI, DB or PROD acceptance.**

## 1. Live-head preflight (mandatory)

Run `get_pr_info #81`, obtain HEAD, check newest commits, look up exact commit workflow runs/jobs. Compare with the SHA in this document. New head = document may be stale, so reconcile first. When a test is red, its log is the gate. Never silently rewrite another developer's status or treat release based on a historic run. The PR is stacked on `feat/rc0551f-c21b-white-atlas-client-avatar-2026-11-17`, not main. Branch status is **Draft**, no merge/deploy confirmation.

**At checkpoint:** after `d03b6a5675cad8b063689ec577a4192389ed04ea` C2.3b3.1 code+tests were committed; a subsequent *documentation* commit may move HEAD. **Exact new SHA CI/Security are pending until verified from GitHub; do not treat older green results as approval.**

## 2. Local machine / DB (user's terminal, 21.11.2026)

| Source | Confirmed value | Consequence |
|---|---|---|
| `git rev-parse --short HEAD` | `c25be48` | User's checkout lags GitHub feature; do not assume new migrations exist locally |
| `git status --short` | ` M db/schema.rb` | Preserve local schema without force checkout/stash/reset |
| `ruby -v` after `export ASDF_RUBY_VERSION=3.4.13` | Ruby **3.4.13**, Bundler **2.6.9** | Shell version is corrected, but already-running :3002 server may still use old runtime |
| Read-only `psql` with `RC_LOCAL_DEV_DATABASE_URL` | **`rails_calendar_rc0551f_c21b_review_20261117`**, role `gor`, PG **16.11**, local **socket** | Correct observed review DB; read-only check does not prove Rails effective DB |
| Original app | port **3001** protected | No changes |
| Working app | `~/rails_calendar_ai_c21c`, port **3002** | Has not been restarted/migrated/reviewed for latest head |
| Railway | Older branch/web/PG volume from prior verification | No deploy/merge/production mutation made in this development series |

**Critical safety:** old scripts `script/rc0551f_c21_backup_preflight.sh` and `script/rc0551f_c21_backup_and_verify.sh` hardcode **`rails_calendar_mvp_preview_20261112`**, NOT the current C2.1b review DB. `script/rc0551f_c21a_migrate_scratch_only.sh` hardcodes an old restored scratch DB/migration. **DO NOT RUN them for this DB.** Before local migration write a new read-only identity/runbook specifically for `rails_calendar_rc0551f_c21b_review_20261117`, verify actual Rails connection and PG socket, then private backup+verified scratch restore of DB and Active Storage with user's approval. Never disclose DB credentials or download backups into chat.

## 3. Milestone ledger (separately scored evidence)

| ID | Result in current feature/history | Code/CI evidence | Still outstanding |
|---|---|---|---|
| `R0.1` Live SHA/status check | Repeated this chat | PR metadata + Actions | Recheck next chat |
| `R0.2` Local DB identify | Read-only **CONFIRMED** | User `psql` terminal: PG16/socket review DB | Rails effective DB; storage/writers |
| `R0.3` Schema drift review | `M db/schema.rb` **CONFIRMED** | user `git status --short` | Do not reset; audit diff safely |
| `R0.4` DB+private storage backup & scratch restore | **NOT CONFIRMED for current review DB** | old scripts target another DB | Backup/restore gate blocks local migration |
| `R0.5` Exact CI + browser QA | Historic CI green, new head pending | links below | New head CI; role/viewport QA |
| `C2.2.1–C2.2.4` Month/day/hour/source and visual contrast | **CODE in Draft** | feature commits `ecc0552` and later | owner :3002 screenshots for new checkout absent |
| `C2.2.5–C2.2.6` Responsive/ACL + unrelated spec workbench flake | Test coverage present, some historic failures | previous Chrome logs in PR | full human validation & no flakes |
| `C2.3a.1–C2.3a.3` Versioned ActivityRecorder and safe AI source links | **CODE + prior CI VERIFIED** | commit `65eec885`, Rails CI [44851693225](https://github.com/TheGor-365/rails_calendar/actions/runs/44851693225), Security [44851693181](https://github.com/TheGor-365/rails_calendar/actions/runs/44851693181) | manual QA/recovery of older sources |
| `C2.3b1` Transactional requirements outbox + bounded replay | **CODE + prior CI VERIFIED** | `1b66cdc`, Rails CI [44852573505](https://github.com/TheGor-365/rails_calendar/actions/runs/44852573505), Security [44852573483](https://github.com/TheGor-365/rails_calendar/actions/runs/44852573483) | Migration **not applied** to local review DB |
| `C2.3b2` Settled AI reply outbox and activity recovery | **CODE + prior CI VERIFIED** | `be6410d`, Rails CI [44854301203](https://github.com/TheGor-365/rails_calendar/actions/runs/44854301203), Security [44854301208](https://github.com/TheGor-365/rails_calendar/actions/runs/44854301208) | UI/source navigation & local migration not accepted |
| `C2.3b3.1` Invitation issued/claimed/submitted/revoked outbox | **CODE + regression tests committed, CURRENT CI PENDING** | `d03b6a5` and preceding model/replayer commits | exact new SHA Rails/Chrome/PG18/Security; local QA |
| `C2.3b3.2` Invitation source replay and old-state compatibility | **PARTIAL CODE** (`C2.3b3.1` includes replay) | current feature | edge cases across claim/submit/revoke, crash/replay |
| `C2.3b4–b7` Service versions, scope/client source adapters, queue metrics, backfill | **NOT VERIFIED** | inspect models before authoring | implementation, CI, QA and migration gate |
| `C2.3c.1–c6` Deterministic projection registry and consistency | **PARTIAL legacy projections** | Calendar OwnerActivity, OwnerArtifacts, Activity Inbox | generalized subscription/rebuild/lag metrics not done |
| `C2.4.1–c8` Validated AI ActionProposal and approved multi-target apply | **NOT VERIFIED** | earlier AI chat/composer ≠ Action Engine | schema/preview/ACL/cost/apply/version/rollback |
| `E1/E2.1–E2.3` Owner/client accounts, invitations, quiz/scope, R-ID | **SUBSTANTIAL EXISTING CODE** | owner/client Rails tests; `IntakeScopeRevision`, `IntakeRequirementSet` | specific browser roles/flow; audit new requirements before edit |
| `E2.4c` R-ID immutable revision diff | **CODE + historic CI** | `4cc24eb` stage, later feature | manual UI source and 12-section acceptance |
| `E2.4a/b/d/e/f` Exact answer provenance, dependencies, dual views, scoped exports | **PARTIAL / NOT VERIFIED** | inspect existing controllers/tests | functionality with E2.4 DoD |
| `E2.5.1–e5` Bilateral exact-version approval and changes | **NOT VERIFIED** | current draft status fields are not bilateral approval | separate actors/digest/version audit |
| `M6.1–m5` Project/tasks/calendar execution | **NOT VERIFIED as complete product flow** | inspect existing milestone resource | actual task/R-ID flow |
| `M7.1–m5` Real artifacts/tests/delivery/acceptance | **NOT VERIFIED** | library exports != durable private delivery artifacts | source-backed files & client acceptance |
| `M8.1–m7` Production hardening, restore, deploy/pilot | **BLOCKED** | no confirmed production release | backup/ACL/security/owner-approved deploy |

**How to mark DONE:** For every ID keep distinct `CODE_SHA`, `TEST_RUNS`, `UI_EVIDENCE`, `DB_EVIDENCE`, `PROD_SHA`, and `BLOCKERS`. Do not set `DONE` just for commit. On next chat reconcile table with **actual latest GitHub head**. Do not remove planned IDs if implementation already exists; mark `VERIFIED` with linked evidence, or `SUPERSEDED` with reason.

## 4. Immediate next *unverified* step

1. **P0 CI for C2.3b3.1:** read exact HEAD and workflow logs, fix true errors, require Rails/Chrome/PG18 fresh+upgrade and Security PASS on that SHA. If green, update this ledger with SHA and run URLs. If red, stop feature expansion and fix first.
2. **R0 local migration safety:** owner has not fetched or migrated new code. Need read-only `Rails effective DB` and `db/schema.rb` diff, then a reviewed backup+scratch-restore procedure specifically for `rails_calendar_rc0551f_c21b_review_20261117`; no `db:migrate` without safety.
3. **C2.3b3.2 / C2.3b4:** once prior CI stable, expand invitation state tests and one new canonical source adapter (service version or scope), preserving no model calls/private data in metadata.

## 5. Registry update rule (mandatory after any code work)

- Commit code and tests with prefix `C2.3b3.1: ...`, then exact SHA CI. Keep code and status separate; status change also has SHA and source run IDs.
- Update THIS file **last** after code changes and evidence: set current feature SHA, test results, local status and one next target. If a documentation-only change triggers a new workflow, distinguish code-tested SHA from documentation SHA and check actual branch protection requirements.
- Add a concise PR #81 comment linking this status and roadmap; optionally sync Notion/Drive/ClickUp with tool result. **GitHub is the canonical tracker**, these other managers are secondary mirrors.
- Before opening new chat ask it to read `docs/RAILS_CALENDAR_NEXT_CHAT_MASTER.md` and this file before acting. New chat must detect newer commits and reconcile, not assume these are always current.