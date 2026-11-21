# Rails Calendar / AI Service Workspace — исполняемый roadmap до production MVP

**Документ:** `docs/RAILS_CALENDAR_MVP_EXECUTION_ROADMAP.md`  
**Редакция:** 2026-11-21, исходный snapshot до следующих коммитов.  
**Внимание:** этот текст — *план и критерии*, а не утверждение, что все перечисленные действия не выполнены. Актуальные исполнения берутся только из `docs/RAILS_CALENDAR_EXECUTION_STATUS.md`, GitHub-кода, CI и последних доказательств. При расхождении старого плана и нового кода сначала проверить код, а затем пометить в реестре `SUPERSEDED` / `VERIFIED` / `PARTIAL`, не переписывать реализованное.

## 0. Цель и границы MVP

Коммерческий сервис разработки, где владелец и клиент могут пройти подтверждённый процесс:

`лид / приглашение / каталог услуг → верифицированный клиент → предварительное интервью → уточнения → 12-раздельное ТЗ → набор R-ID → две независимые проверки точной версии → проект/задачи/сроки → исполнение/файлы/тесты → сдача → отзыв/приёмка → аналитика коммерческой воронки`.

ИИ — вспомогательный производственный контур: **один явно оплаченный вызов → сохранённый исходный ответ → подтверждённое или отклонённое предлагаемое изменение → новое неизменяемое состояние источника → бесплатные детерминированные проекции во все подходящие места**. AI suggestions не равно утверждённое ТЗ; сохранение AI-ответа не равно публикация. Новые клиентские условия, платежи, удаление и production deploy требуют отдельных проверенных полномочий и подтверждений человека.

Production MVP = не просто деплой. Публично доступный, управляемый рабочий процесс с тестовой, затем разрешённой реальной заявкой, сохранёнными артефактами, приватностью, доказанным восстановлением, monitoring/rollback и эксплуатационными инструкциями. Полную цепочку получения оплаты считать отдельным коммерческим gate; не имитировать успешные выплаты.

## 1. Инварианты для всех этапов

1. **Source of truth:** `ProjectIntake`, `ClientRequestInvitation`, `IntakeScopeRevision`, `IntakeRequirementSet`, `IntakeSpecVersion`, `OwnerAiConversation/OwnerAiMessage`, `AiSpendEntry`, `ServiceOfferingVersion` и будущие Project/Task. Календарь, библиотека, журнал — только производные, подчинённые ACL представления.
2. **Workspace isolation:** каждый source и event связан с проверенным workspace; `workspace_id = NULL` не даёт legacy-объектам расширенного доступа. Роли owner/client/guest/other-owner, owner без workspace обязаны иметь negative-тесты.
3. **Версионность/идемпотентность:** источник, редакция, действие, событие и доставка однозначны. Retry не порождает двойную карточку/списание; старые версии нельзя переписать молча.
4. **AI-cost gate:** согласие, лимит, единственный `AiSpendEntry`, корректные `reserved/settled/uncertain/cancelled`; неизвестный биллинг — без автоматического повторного вызова.
5. **Atomicity:** каноническая запись + outbox в одной транзакции; внешние эффекты — после commit через разрешённый обработчик. Не требовать распределённых транзакций.
6. **Privacy/storage:** оригиналы и вложения приватны, минимальные event metadata; только проверенные ссылки с повторным ACL. Не хранить токены, KYC, контент ответов клиента в outbox/публичных уведомлениях; отсутствие файла не маскировать фальшивым download.
7. **Human approval:** AI-предложения проверяются сервером; клиентский publish, согласование, изменение финансовых условий, destructive, email/notification to external users, merge/deploy — через явное действие.
8. **Time semantics:** `occurred_at` (факт) не равен `scheduled_for`/консультации. Месяц → день → час → источник. Прошедшие события визуально отделены, но читаемы.
9. **No destructive maintenance:** никакого `db:reset`, `db:prepare` на ценной БД, `git clean`, `git checkout -- db/schema.rb`, force-push, удаления томов или файлов без отдельной доказанной процедуры.
10. **Доказательства:** `CODE_COMMITTED`, `CI_VERIFIED`, `BROWSER_ACCEPTED`, `MIGRATION_APPLIED_LOCAL`, `DEPLOYED_PRODUCTION`, `TRANSACTION_VERIFIED` — разные статусы, нельзя считать один другим.

## 2. Последовательность работ. Подпункты и DoD

### R0. Сохранение существующей базы и release-гигиена (непрерывный gate)
- **R0.1** Перед началом каждого чата: PR/head SHA, свежие CI, текущий статус/мастер в том же SHA; проверить, что локальный код и production не равны head автоматически.
- **R0.2** Идентифицировать локальную target DB: точное имя, пользователь, сервер, socket, версия, Rails effective config, не раскрывая credentials. Отдельно current review DB и test DB.
- **R0.3** Объяснить drift `db/schema.rb`, получить текущую схему и `schema_migrations` только чтением; не overwrite/stash.
- **R0.4** Наличие приватного backup PostgreSQL **и** Active Storage, checksum, проверенный restore в явно выделенную scratch DB. Бэкап, просто созданный без restore, не считается достаточным.
- **R0.5** Прогон Rails/Chrome/PG fresh+upgrade/Security на точном SHA, затем локальные визуальные роли и viewport; production только после owner signoff.
- **R0.6** Чувствительная конфигурация и стоимость provider по принципу least privilege; production Ruby исправлена; staged migration/rollback план.

**DoD:** зафиксированы DB identity, recovery evidence, точный SHA и права, план возврата. Все действия с БД разделены на read-only preflight, backup+restore и (лишь затем) migration с явным согласием.

### C2.2. Объединённый календарь и навигация (есть код, ручная приёмка не доказана)
- **C2.2.1** Общее отражение Consultation и owner activities с корректными counts: месяц, день и час; календарь не создаёт новых фактов.
- **C2.2.2** Контраст отдельных клеток, чисел, границ, прошедших/сегодня/будущих дней; читаемое событие и time.
- **C2.2.3** Сверху дня видимая хронология активности, не только час 17 вне viewport; раскрываемые события непосредственно в соответствующем часе.
- **C2.2.4** Навигация месяц → день → час → конкретный исходный объект / его версия, включая AI разговор, заявку, результат, файл. Нет случайных чужих ссылок.
- **C2.2.5** Доступность: 320/390/768/1440, клавиатура/focus, RU/EN/HY/ES, owner/client/guest/foreign-owner, 0/1/many и overlapping consultations.
- **C2.2.6** Устранение Chrome regression spec workbench anchor navigation, если ещё существует на актуальном SHA.

**DoD:** exact-SHA automated green + владельцем приняты конкретные скриншоты на реальном браузере; никаких списаний на просмотр.

### C2.3a. Канонические owner events и точные source links (существует, CI был green)
- **C2.3a.1** `Activity::Recorder` — legacy key + версия и безопасность workspace/metadata.
- **C2.3a.2** `Activity::SourceLinks` — переход из owner ledger на сохранённую беседу при валидном settled response и ACL.
- **C2.3a.3** Календарь, библиотека, журнал используют тот же resolver; negative tests.
- **C2.3a.4** Проверка browser UX и invalid/deleted source fallback, пропуски/дубли.

**DoD:** zero charges on read/replay; cross-workspace deny; источники доступны только с правами. Не пересоздавать сделанный код.

### C2.3b. Транзакционный outbox и восстановление (по источникам, постепенный rollout)
- **C2.3b1** `DomainOutboxEvent` таблица и key `(workspace, type, id, source_version, kind)`, in-transaction enqueue для `IntakeRequirementSet`, bounded workspace-only replay, retry, test rollback. **Есть код и green CI; НЕ применено к локальной review DB автоматически.**
- **C2.3b2** `OwnerAiMessage` при первом `assistant/settled` + settled ledger → private outbox `ai_reply_saved`, immediate activity, bounded replay, source link; **есть код и green CI; локальная DB не мигрирована**.
- **C2.3b3** `ClientRequestInvitation` source adapters: issued/claimed/submitted/revoked как отдельные version-safe события со строгими timestamps/ACL. По одному переходу на PR с обратной совместимостью и тестами; не включать старые приглашения массово без dry-run.
- **C2.3b4** `ServiceOfferingVersion`: только сохранённые, реально approved/published immutable версии; не публиковать сервис от имени AI. Взаимодействие с `ServiceOffering#published_version_id` отдельно от создания черновика.
- **C2.3b5** `ProjectIntake`/`IntakeScopeRevision`: новые клиентские и owner версии; отдельная приватность client draft/owner draft; источник за каждым событием. Не путать техническое подтверждение с юридическим.
- **C2.3b6** Reconciliation health: pending/failed/delivered, last lag, retry count, dead letter, безопасный dry-run; operator-only bounded trigger, идемпотентный replay без provider call. Перейти к настоящему worker только после monitoring, rate limit и owner permission.
- **C2.3b7** Backfill миграций: нет blind scanning production; проверенный план resume/rollback, paging, telemetry и миграция sandbox до release.

**DoD:** для каждого источника тест `transaction rollback`, repeated replay, source removed/foreign, privacy, no extra AI charge, no duplicated ActivityEvent; код и операционный runbook.

### C2.3c. Детерминированные проекции на целевые страницы
- **C2.3c1** Единый subscription/registry для `kind → allowed audience + destinations` с explicit authorization.
- **C2.3c2** Месяц/день/час: occurrence vs scheduled, сортировка, overflow, timezone.
- **C2.3c3** Библиотека: только persisted artifacts, source/lineage/version/checksum, реальные экспорты без несуществующих файлов; archive/search/filter.
- **C2.3c4** Owner notifications: unread/read receipts per owner, dedup, safe deep links; client notifications отдельно.
- **C2.3c5** Project/task timeline (когда появятся объекты), per-milestone schedule, sensitive/private projections, consistency KPIs.
- **C2.3c6** Crash recovery, delayed delivery, rebuild from source, lag metrics, no duplicate charges.

**DoD:** один искусственный canonical write отображается ровно в разрешённых местах и восстанавливается после потери projection; другие owners/clients/guests не видят исходное содержимое.

### C2.4. AI Action Engine — прикладной ИИ на страницах
- **C2.4.1** Регистр разрешённых операций и целевых объектов; typed strict JSON Schema, no arbitrary commands/routes/SQL/provider URLs.
- **C2.4.2** Повторно используемый конструктор контекста из разрешённых source snapshots, с защитой от prompt injection и проверенным scope/consent.
- **C2.4.3** Доказуемый единый ledger на запрос, quota/budget, uncertain handling, idempotent retry без повторной внешней оплаты.
- **C2.4.4** `ActionProposal`: target, source version/digest, explicit operation, patch, assumptions, evidence, conflicts, confidence, review-required flag.
- **C2.4.5** Preview before/after, human edits, reject/accept/partially apply, stale version guard, conflict reconciliation, audited actor.
- **C2.4.6** Transactional apply + outbox, forward to relevant views; rollback через новую версию, не silent in-place overwrite.
- **C2.4.7** Реальные файлы: MIME/type/size/checksum, private durable storage, versioned download; no public blobs by default.
- **C2.4.8** Page-specific actions (owner profile, service, invite, AI chats, calendar, spec, project) по одной способности с e2e tests и затратами.

**DoD:** один разрешённый платный AI-результат → сохранённое предложение → подтверждённый source revision → синхронные views без нового платного запроса. Деструктивное/финансовое/клиентское действие без подтверждения невозможно.

### E1–E2.3. Клиентские входы, интервью, бриф, версия ТЗ (проверить, НЕ дублировать)
- **E1.1** Verified client account/cabinet, разделение ролей, самостоятельная заявка и выбор 0–6 опубликованных услуг, immutable selections.
- **E1.2** One-time owner invitation, TTL, claim, revoke, seed, owner/client visibility, privacy.
- **E2.1** Клиентские вводные, короткие варианты, `unknown/choose for me`, draft, return/resume без потери.
- **E2.2** 12 секций discovery и owner/client scope snapshots, dynamic clarifications, статус unknown/conflicts.
- **E2.3** `IntakeRequirementSet`: стабильные R-ID, ручное редактирование, критерии приёмки, append-only версии; diff в E2.4c уже добавлен (фактический UI проверить).

**DoD:** действующий учебный сценарий показан в браузере, source versions сохраняются, ACL и negative tests зелёные. После полного аудита дописывать только пробелы.

### E2.4. Техническое ТЗ из 12 разделов с provenance
1. Бизнес-цель и контекст.
2. Аудитории и роли.
3. Страницы и сценарии пользователей.
4. Функциональные требования.
5. Данные и интеграции.
6. Нефункциональные требования.
7. Материалы, дизайн и контент.
8. Критерии приёмки.
9. Ограничения и исключения.
10. Риски, зависимости, неизвестное.
11. Декомпозиция задач.
12. Предварительная не обязывающая оценка.

- **E2.4a** По каждому `R-014` — точная исходная версия, конкретный ответ/секция/пункт, actor и link; если source missing, показать неизвестное, не выдумывать ответ.
- **E2.4b** Статусы `confirmed/suggested/unknown/excluded`, dependency graph, cycle rejection, exclusions, acceptance verifiability. "confirmed" у ответа не означает подтверждение ТЗ обеими сторонами.
- **E2.4c** Immutable `v1/v2/v3` diff, add/changed/removed, безопасные owner views; уже есть код и green CI в PR, browser не подтверждён.
- **E2.4d** Два представления одного источника: клиентское бизнес-описание и техническое owner с data/API/stack/dependencies/tests.
- **E2.4e** AI-assisted candidate suggestions только после consent, все решения owner-reviewed; unknowns, risks, cost/timeline disclaimers.
- **E2.4f** Versioned real PDF/TXT/Markdown exports, контент/lineage, ACL и retention, тест воспроизводимости.

**DoD:** клиент видит точную версию ТЗ без чужих приватных деталей, исполнитель — проверяемые исходные ответы, статус и критерии, каждое новое изменение создаёт новую версию и diff.

### E2.5. Двустороннее согласование конкретной редакции
- **E2.5.1** Owner review and explicit approval on `spec_version_id` + digest + timestamp.
- **E2.5.2** Client review of EXACT owner-shared version, explicit approve or request changes; no coercive or implicit acceptance.
- **E2.5.3** Change request → new draft version, previous approved immutable, stale approval invalidation.
- **E2.5.4** Notifications with source scoped links; audit log and retention; no fake legal signature.
- **E2.5.5** UX workflow with rights, verification and clear statuses; separate external legal contract if required.

**DoD:** independently verified owner+client actions on exact digest, decision/change history and no retroactive overwrite.

### M6. Проект/задачи/календарь разработки
- **M6.1** Create Project from approved spec only with explicit confirmation; no automatic unauthorized client obligations.
- **M6.2** Immutable scope source, milestones, tasks, owner roles/assignments, dependencies, estimate ranges, acceptance IDs.
- **M6.3** Calendar activity / scheduled milestones / completed events with correct time semantics, project links and notifications.
- **M6.4** Task files, change logs, owner/client comments, technical evidence, issue tracker links, scoped AI assistance.
- **M6.5** Project summary/forecast/alerts with accepted vs proposed scope and version drift.

**DoD:** one approved scope yields auditable plan and daily execution view, no task loses link to `R-ID`.

### M7. Исполнение, тесты, сдача и приёмка
- **M7.1** Safe private file storage with checksum, version, scoped download, restore verification and quotas.
- **M7.2** Link deliverable commits/PRs/deploy previews/screenshots/tests to tasks and R-IDs.
- **M7.3** Structured QA, test evidence, review by owner; client acceptance or change request per deliverable.
- **M7.4** Handoff pack: accessible files, changelog, instructions, limitations, provenance, signed-off revision.
- **M7.5** Repeat customer, feedback and issue follow-up, no invented testimonials.

**DoD:** fictional end-to-end, then permitted real-client pilot shows actual artifact, evidence, explicit acceptance.

### M8. Production-ready operations, release, commercial validation
- **M8.1** Dependency/security Ruby & gems, patch CVEs, Brakeman/bundle-audit/secret scanning, CSP/XSS/CSRF/auth/IDOR, limiting.
- **M8.2** PostgreSQL 18 staged migration rehearsal from actually deployed DB, rollback drills; backups + tested restore, retention + storage durability.
- **M8.3** Separate environments, migrations under explicit deployment plan, Railway config/volume/bucket & secrets, no source branch accident.
- **M8.4** CI Rails/controller + Chrome/system + PG18 new/upgrade + Security all on exact release SHA, no skips/flakes, owner desktop/mobile QA.
- **M8.5** Observability: error logs, queue metrics, latency/cost, billed/uncertain handling, idempotency, audit access, incident and restore runbook.
- **M8.6** Authorized staged deploy → smoke tests → controlled publication, production rollback procedure, release notes and signoff.
- **M8.7** Pilot: consented legitimate test customer, real workflow, privacy/legal terms and service boundaries, measured lead-to-approved-to-delivery conversion, invoice/pay route separately verified.

**DoD:** production MVP available, secure and recoverable, core workflow proven. GitHub green does not equal deployment. Release note contains exact SHA, database, auth/rollback, smoke screenshots and user approval.

## 3. Приёмка для каждого подпункта

Требовать отдельно:
- `SPECIFIED`: контракт и DoD записаны в GitHub.
- `CODE_COMMITTED`: hash SHA and touched files.
- `CI_VERIFIED`: exact SHA, workflow IDs, count of tests, 0 errors, security.
- `LOCAL_BROWSER_VERIFIED`: screenshot + role + viewport + synthetic acceptance scenario.
- `DB_VERIFIED`: identity, backup, restore, migration evidence on explicit target.
- `DEPLOYED`: URL, production SHA, release auth, smoke, rollback evidence.
- `FINANCIAL_REALITY_VERIFIED`: реальные лид/оплата/payout, не регистрации и демо.

Пункты могут иметь несколько статусов. Для `DONE` подпункта обязательно соответствующее DoD; прежняя реализация не переписывается без открытого регрессионного дефекта.

## 4. Правило актуальности

Приоритет информации: **новый подтверждённый GitHub-код + SHA → exact-SHA CI → свежие датированные скриншоты/локальные выводы пользователя → `docs/RAILS_CALENDAR_EXECUTION_STATUS.md` → этот roadmap → старые master/Handoff/Notion/Drive**. Не считай, что GitHub знает localhost; не считай, что пользовательский checkout переключился после GitHub-коммита. Если документы и код расходятся, исправь документы и приложи доказательство. Не удаляй старые кейсы/активы из-за устаревшего checklist.