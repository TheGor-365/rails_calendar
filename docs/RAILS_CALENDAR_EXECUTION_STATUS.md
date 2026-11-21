# Rails Calendar — execution status / single entrypoint for next chat

**As-of:** 2026-11-21; **type:** date-stamped checkpoint, not realtime.  
**Live source:** GitHub [PR #81](https://github.com/TheGor-365/rails_calendar/pull/81), latest **HEAD SHA + code + exact-SHA CI**. Every new assistant MUST fetch fresh SHA and refresh this file.  
**Companion docs:** [NEXT_CHAT_MASTER](RAILS_CALENDAR_NEXT_CHAT_MASTER.md) · [MVP_EXECUTION_ROADMAP](RAILS_CALENDAR_MVP_EXECUTION_ROADMAP.md).  
**Status notation:** `CODE` = in feature branch; `CI` = exact prior SHA passed; `UI` = manual acceptance; `DB` = local migration; `PROD` = authorized deployment. **A green CI is not UI, DB or PROD acceptance.**

## 1. Live-head preflight (mandatory)

Run `get_pr_info #81`, obtain HEAD, check newest commits, look up exact commit workflow runs/jobs. Compare with the SHA in this document. New head = document may be stale, so reconcile first. When a test is red, its log is the gate. Never silently rewrite another developer's status or treat release based on a historic run. The PR is stacked on `feat/rc0551f-c21b-white-atlas-client-avatar-2026-11-17`, not main. Branch status is **Draft**, no merge/deploy confirmation.

**Last fully verified checkpoint:** `d03742dc5fafd063f1d7cfd305290330c0dcc93e` (C2.3b3.1 code + status), [Rails CI #44902492224](https://github.com/TheGor-365/rails_calendar/actions/runs/44902492224) **SUCCESS**, [Security #44902492221](https://github.com/TheGor-365/rails_calendar/actions/runs/44902492221) **SUCCESS**. Original C2.3b3.1 code SHA `675edf8` also passed Rails 370/6114, Chrome 47/726, PG18 fresh/upgrade and Security. **New code checkpoint:** `4f2faf5eb18ed5b408c26921db4c06422bfdcc2e` (C2.3b3.2 + C2.3b4 tests and service publication adapter), code CI [#44905973751](https://github.com/TheGor-365/rails_calendar/actions/runs/44905973751), Security [#44905973746](https://github.com/TheGor-365/rails_calendar/actions/runs/44905973746): **PENDING at writing**. A following documentation SHA `d7790bb` and this ledger update also move HEAD; recheck every actual commit/workflow and do not conflate versions.

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

**New read-only owner confirmation:** `RC_LOCAL_DEV_DATABASE_URL` connects to `rails_calendar_rc0551f_c21b_review_20261117`, PostgreSQL `160011`, local socket, and `to_regclass('public.domain_outbox_events') IS NOT NULL` returned `f`: outbox migration is **NOT applied locally**, exactly as expected. The `git diff --stat -- db/schema.rb` command displayed no output in this turn; it does NOT by itself prove the file is clean or unchanged. Inspect both staged/unstaged status before any pull. This still does not prove the *running Rails process* uses the same DB.

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
| `C2.3b3.1` Invitation issued/claimed/submitted/revoked outbox | **CODE + CI VERIFIED** on `675edf8` | [Rails CI #44902199313](https://github.com/TheGor-365/rails_calendar/actions/runs/44902199313), [Security #44902199307](https://github.com/TheGor-365/rails_calendar/actions/runs/44902199307); 370/6114 Rails, 47/726 Chrome, PG18 fresh+upgrade | local browser, backup/restore and review DB migration **NOT VERIFIED** |
| `C2.3b3.2` Invitation transition edge cases and replay provenance | **CODE_COMMITTED · CI PENDING** | `4f2faf5`: claim/submit/no-op/revocation rollback tests and timestamp equality guard; [CI pending #44905973751](https://github.com/TheGor-365/rails_calendar/actions/runs/44905973751) | exact-SHA CI, human QA, local migration |
| `C2.3b4` Approved service publication/unpublication audit → outbox | **CODE_COMMITTED · CI PENDING** | `4f2faf5`: `ServiceOfferingPublication` canonical audit, private after-create enqueue, owner-only activity/replay/links, 4 locales, rollback/ACL tests; [contract](RC0551F_C23B32_B4_SERVICE_PUBLICATION_2026-11-21.md) | exact-SHA CI, human QA, local migration; no client publication by replay |
| `C2.3b5–b7` Scope/client source adapters, reconciliation metrics and backfill | **NOT VERIFIED** | next code slices | implementation, CI, QA, DB safety gate |
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

1. **P0 Verify C2.3b3.2 and C2.3b4 code SHA `4f2faf5`:** check [CI #44905973751](https://github.com/TheGor-365/rails_calendar/actions/runs/44905973751), [Security #44905973746](https://github.com/TheGor-365/rails_calendar/actions/runs/44905973746), inspect failed job logs and repair before claiming CI_VERIFIED. Prior `d03742d` was green but is NOT proof for new code. Check newer docs commits separately.
2. **R0 local migration safety (BLOCKER):** owner has not fetched or migrated new code. Use [R0.4 review DB safety runbook](RC0551F_REVIEW_DB_BACKUP_MIGRATION_GATE.md) for read-only `Rails effective DB` and `db/schema.rb` diff, then private backup+scratch restore specifically for `rails_calendar_rc0551f_c21b_review_20261117`; no `db:migrate` without safety and explicit owner action.
3. **C2.3b5 next after C2.3b4 CI:** inspect already-existing `ProjectIntake` and immutable `IntakeScopeRevision`; add source adapters one at a time with explicit owner/client visibility, no private content in event metadata or paid AI. Then C2.3b6 replay metrics/backfill dry-run, C2.3c projections.

## 5. Registry update rule (mandatory after any code work)

- Commit code and tests with prefix `C2.3b3.1: ...`, then exact SHA CI. Keep code and status separate; status change also has SHA and source run IDs.
- Update THIS file **last** after code changes and evidence: set current feature SHA, test results, local status and one next target. If a documentation-only change triggers a new workflow, distinguish code-tested SHA from documentation SHA and check actual branch protection requirements.
- Add a concise PR #81 comment linking this status and roadmap; optionally sync Notion/Drive/ClickUp with tool result. **GitHub is the canonical tracker**, these other managers are secondary mirrors.
- Before opening new chat ask it to read `docs/RAILS_CALENDAR_NEXT_CHAT_MASTER.md` and this file before acting. New chat must detect newer commits and reconcile, not assume these are always current.