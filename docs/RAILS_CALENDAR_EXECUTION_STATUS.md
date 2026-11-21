# Rails Calendar — execution status / single entrypoint for next chat

**As-of:** 2026-11-21; **type:** date-stamped checkpoint, not realtime.  
**Live source:** GitHub [PR #81](https://github.com/TheGor-365/rails_calendar/pull/81), latest **HEAD SHA + code + exact-SHA CI**. Every new assistant MUST fetch fresh SHA and refresh this file.  
**Companion docs:** [NEXT_CHAT_MASTER](RAILS_CALENDAR_NEXT_CHAT_MASTER.md) · [MVP_EXECUTION_ROADMAP](RAILS_CALENDAR_MVP_EXECUTION_ROADMAP.md).  
**Status notation:** `CODE` = in feature branch; `CI` = exact prior SHA passed; `UI` = manual acceptance; `DB` = local migration; `PROD` = authorized deployment. **A green CI is not UI, DB or PROD acceptance.**

## 1. Live-head preflight (mandatory)

Run `get_pr_info #81`, obtain HEAD, check newest commits, look up exact commit workflow runs/jobs. Compare with the SHA in this document. New head = document may be stale, so reconcile first. When a test is red, its log is the gate. Never silently rewrite another developer's status or treat release based on a historic run. The PR is stacked on `feat/rc0551f-c21b-white-atlas-client-avatar-2026-11-17`, not main. Branch status is **Draft**, no merge/deploy confirmation.

**Last fully CI-verified branch checkpoint:** `30eb026b6bdcb50c0bfd2e78f680fc5b3f8a4459` (C2.3b6c1 source/retry safety + documentation), [Rails CI #44923450963](https://github.com/TheGor-365/rails_calendar/actions/runs/44923450963) **SUCCESS**, [Security #44923450762](https://github.com/TheGor-365/rails_calendar/actions/runs/44923450762) **SUCCESS**. C2.3b6c1 functional SHA `39e8096` already verified independently: 391 Rails tests/6390 assertions, 47 Chrome tests/726 assertions, PG18 fresh/upgrade and Security PASS. **New R0.4a preflight + offline test + workflow code checkpoint:** `5048a7139e6ba1a2f92b64201788e444bcaeb5a6`, GitHub [Rails CI #44932336413](https://github.com/TheGor-365/rails_calendar/actions/runs/44932336413), [Security #44932336443](https://github.com/TheGor-365/rails_calendar/actions/runs/44932336443) were **QUEUED at writing**; subsequent runbook and ledger documentation commits also move HEAD. Check current live branch and exact-SHA workflows before marking preflight CI_VERIFIED.

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

**Latest local environment and storage proof (user 21-Nov 2026):** Ruby `3.4.13`, Rails `8.1.4.1`, 92 Bundler gems, `bundle check` PASS. Read-only Rails runner SELECT returned `rails_calendar_rc0551f_c21b_review_20261117|gor|160011|socket|false`, proving the standalone development Rails process uses the exact local PG16.11 review DB (outbox migration absent). Additional read-only Rails runner printed `ACTIVE_STORAGE=local`. On disk, `storage/` is a **real directory, not symlink**, owned by `gor`, mode **775**; its **group is writable** and the group's membership, nested symlinks, file totals and disk space have not yet been inspected. This is not proof of an exposure, but is a media backup/security review gate. Already-running :3002 DB/process remains separately UNVERIFIED. Local `db/schema.rb M` preserved; no local migration, backup, restore, permissions change, server restart or Railway deployment.

**Critical safety:** old scripts `script/rc0551f_c21_backup_preflight.sh` and `script/rc0551f_c21_backup_and_verify.sh` hardcode **`rails_calendar_mvp_preview_20261112`**, NOT the current C2.1b review DB. `script/rc0551f_c21a_migrate_scratch_only.sh` hardcodes an old restored scratch DB/migration. **DO NOT RUN them for this DB.** Before local migration write a new read-only identity/runbook specifically for `rails_calendar_rc0551f_c21b_review_20261117`, verify actual Rails connection and PG socket, then private backup+verified scratch restore of DB and Active Storage with user's approval. Never disclose DB credentials or download backups into chat.

## 3. Milestone ledger (separately scored evidence)

| ID | Result in current feature/history | Code/CI evidence | Still outstanding |
|---|---|---|---|
| `R0.1` Live SHA/status check | Repeated this chat | PR metadata + Actions | Recheck next chat |
| `R0.2` Local DB identity (psql + Rails) | **READ-ONLY VERIFIED** | User Rails runner `rails_calendar_rc0551f_c21b_review_20261117|gor|160011|socket|false` | Live :3002 process connection remains separately unverified |
| `R0.3` Schema drift review | `M db/schema.rb` **CONFIRMED** | user `git status --short` | Do not reset; audit diff safely |
| `R0.4a` Exact review DB + local storage preflight | **CODE_COMMITTED · CI PENDING; NOT EXECUTED LOCALLY** | script `script/rc0551f_r04_review_db_preflight.sh`, offline deny tests + workflow at `5048a71`; [CI #44932336413](https://github.com/TheGor-365/rails_calendar/actions/runs/44932336413) and [Security #44932336443](https://github.com/TheGor-365/rails_calendar/actions/runs/44932336443) were QUEUED; [runbook](RC0551F_REVIEW_DB_BACKUP_MIGRATION_GATE.md) | group/member + nested symlink and free disk audit; do not assume script is in older local checkout |
| `R0.4b` Private DB+storage backup and isolated scratch restore | **NOT EXECUTED / BLOCKED** | old scripts target WRONG DB; no reviewed backup writer for current DB yet | explicit permission, stopped writers, exact source/role/socket, private 0700/0600 archive, new scratch DB, count/media/checksum verification |
| `R0.5` Exact CI + browser QA | Historic CI green, new head pending | links below | New head CI; role/viewport QA |
| `C2.2.1–C2.2.4` Month/day/hour/source and visual contrast | **CODE in Draft** | feature commits `ecc0552` and later | owner :3002 screenshots for new checkout absent |
| `C2.2.5–C2.2.6` Responsive/ACL + unrelated spec workbench flake | Test coverage present, some historic failures | previous Chrome logs in PR | full human validation & no flakes |
| `C2.3a.1–C2.3a.3` Versioned ActivityRecorder and safe AI source links | **CODE + prior CI VERIFIED** | commit `65eec885`, Rails CI [44851693225](https://github.com/TheGor-365/rails_calendar/actions/runs/44851693225), Security [44851693181](https://github.com/TheGor-365/rails_calendar/actions/runs/44851693181) | manual QA/recovery of older sources |
| `C2.3b1` Transactional requirements outbox + bounded replay | **CODE + prior CI VERIFIED** | `1b66cdc`, Rails CI [44852573505](https://github.com/TheGor-365/rails_calendar/actions/runs/44852573505), Security [44852573483](https://github.com/TheGor-365/rails_calendar/actions/runs/44852573483) | Migration **not applied** to local review DB |
| `C2.3b2` Settled AI reply outbox and activity recovery | **CODE + prior CI VERIFIED** | `be6410d`, Rails CI [44854301203](https://github.com/TheGor-365/rails_calendar/actions/runs/44854301203), Security [44854301208](https://github.com/TheGor-365/rails_calendar/actions/runs/44854301208) | UI/source navigation & local migration not accepted |
| `C2.3b3.1` Invitation issued/claimed/submitted/revoked outbox | **CODE + CI VERIFIED** on `675edf8` | [Rails CI #44902199313](https://github.com/TheGor-365/rails_calendar/actions/runs/44902199313), [Security #44902199307](https://github.com/TheGor-365/rails_calendar/actions/runs/44902199307); 370/6114 Rails, 47/726 Chrome, PG18 fresh+upgrade | local browser, backup/restore and review DB migration **NOT VERIFIED** |
| `C2.3b3.2` Invitation transition edge cases and replay provenance | **CODE + CI VERIFIED** | `8aa71eb` [Rails CI #44906134943](https://github.com/TheGor-365/rails_calendar/actions/runs/44906134943), [Security #44906134900](https://github.com/TheGor-365/rails_calendar/actions/runs/44906134900) SUCCESS | human UI/DB/production still not verified |
| `C2.3b4` Service publish/unpublish immutable audit → outbox | **CODE + CI VERIFIED** | same verified `8aa71eb`; [contract](RC0551F_C23B32_B4_SERVICE_PUBLICATION_2026-11-21.md) | no owner browser QA or local DB migration; no AI auto-publication |
| `C2.3b5` Scoped `ProjectIntake` and client/owner `IntakeScopeRevision` outbox | **CODE + CI VERIFIED** | `3b32ffc` [Rails CI #44911999026](https://github.com/TheGor-365/rails_calendar/actions/runs/44911999026) and [Security #44911999036](https://github.com/TheGor-365/rails_calendar/actions/runs/44911999036) SUCCESS; [contract](RC0551F_C23B5_INTAKE_SCOPE_SOURCE_2026-11-21.md) | exact historical scope permalink, human QA, local migration still NOT DONE |
| `C2.3b6a` Owner outbox aggregates and bounded candidate preview | **CODE + CI VERIFIED** | `981ebf1`, [Rails CI #44914065690](https://github.com/TheGor-365/rails_calendar/actions/runs/44914065690), [Security #44914065635](https://github.com/TheGor-365/rails_calendar/actions/runs/44914065635) SUCCESS; [contract](RC0551F_C23B6A_OUTBOX_HEALTH_DRYRUN_2026-11-21.md) | local user DB not migrated; no production; pure read-only health API |
| `C2.3b6b1` Owner-only GET diagnostics UI | **CODE + CI VERIFIED** | `306fdc1`; [Rails #44922808417](https://github.com/TheGor-365/rails_calendar/actions/runs/44922808417) & [Security #44922808402](https://github.com/TheGor-365/rails_calendar/actions/runs/44922808402) **SUCCESS**; [UI contract](RC0551F_C23B6B1_OUTBOX_OPERATOR_READONLY_UI_2026-11-21.md) | local browser role/viewport QA, local DB migration, PROD NOT DONE |
| `C2.3b6c1` Stale failure/terminal retry accounting + regression tests | **CODE + CI VERIFIED** | `39e8096`; [Rails #44923093762](https://github.com/TheGor-365/rails_calendar/actions/runs/44923093762) SUCCESS (391/6390 Rails; 47/726 Chrome; PG18 fresh+upgrade PASS), [Security #44923093845](https://github.com/TheGor-365/rails_calendar/actions/runs/44923093845) SUCCESS; [contract](RC0551F_C23B6C1_OUTBOX_RETRY_SAFETY_2026-11-21.md) | live parallel-worker stress, local DB migration/browser QA, PROD NOT DONE |
| `C2.3b6b2/C2.3b6c2` Supervised replay action and concurrency/actor audit | **NOT IMPLEMENTED · BLOCKED BY R0.4** | no POST replay endpoint/scheduler or new AI charge | private backup+scratch restore, explicit owner action, CSRF/rate/concurrency/limits |


| `C2.3b7` Dry-run backfill, bounded pacing and reconciliation | **NOT IMPLEMENTED / NOT VERIFIED** | future substep | no production scans or auto-backfill |

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

1. **P0 verify R0.4a preflight code SHA `5048a71`:** inspect [Rails #44932336413](https://github.com/TheGor-365/rails_calendar/actions/runs/44932336413), [Security #44932336443](https://github.com/TheGor-365/rails_calendar/actions/runs/44932336443) and exact latest branch checks, fix any offline guard/test failures. C2.3b6c1 was already green at `30eb026`; do not redo.
2. **R0.4a owner read-only checklist:** inspect `storage/` group membership, nested symlink count, file/disk size; user can run read-only diagnostics without pulling new migrations. Review the new exact-db preflight before executing it. Current storage mode is 775 (group-writable). **R0.4b** private DB+media backup and verified isolated restore still NOT done and requires a separately reviewed script and user approval. Never use old wrong-db backup scripts or auto-migrate.
3. **Development next:** after R0.4a CI, prepare/review exact-db R0.4b backup+scratch-restore workflow (do not run unapproved). Independently C2.3b6c2 concurrent-worker stress, C2.3b7 read-only paged backfill dry-run, C2.3c deterministic projections; then C2.4, E2.4/E2.5 and M6–M8. Keep separate CODE/CI/UI/DB/PROD evidence.

## 5. Registry update rule (mandatory after any code work)

- Commit code and tests with prefix `C2.3b3.1: ...`, then exact SHA CI. Keep code and status separate; status change also has SHA and source run IDs.
- Update THIS file **last** after code changes and evidence: set current feature SHA, test results, local status and one next target. If a documentation-only change triggers a new workflow, distinguish code-tested SHA from documentation SHA and check actual branch protection requirements.
- Add a concise PR #81 comment linking this status and roadmap; optionally sync Notion/Drive/ClickUp with tool result. **GitHub is the canonical tracker**, these other managers are secondary mirrors.
- Before opening new chat ask it to read `docs/RAILS_CALENDAR_NEXT_CHAT_MASTER.md` and this file before acting. New chat must detect newer commits and reconcile, not assume these are always current.