# R1A — первый ограниченный production-release candidate (RC051)

**Дата: 2026-11-23. Статус: подготовка к релизу; НЕ опубликовано; production migration НЕ разрешена.**

## Цель и область

- Production Railway: проект `rails-calendar-ai-workspace`, service `rails-calendar-ai-web`, `production`, branch `feat/client-owner-pilot-2026-11-13`, deployed SHA `90d7a817651ba1bffe174d3f800d32988a664169` (2026-11-13, `SLEEPING` при проверке).
- Релизная ветка `release/rc-r1a-ai-spend-2026-11-23` основана на RC051 `5fc831d67f5ecd39eae4741156c09521d0e8db17` (PR #50). По отношению к действующему коду ровно **11 коммитов, 10 файлов, одна миграция** `20261113213000_create_ai_spend_entries.rb`.
- Функция R1A — защищённый Grok intake + учет стоимости, блокировка двойной оплаты, ручной fallback; **не весь Owner AI Chat**. Ветка release НЕ подключена к Railway, production не меняется.
- Новый CI `.github/workflows/r1a_pg18_upgrade.yml` загружает точную production-схему из Git в изолированный PostgreSQL 18 GitHub Actions, создаёт синтетического owner/intake, применяет ровно одну миграцию и проверяет сохранность строк. Никакие реальные базы, файлы или xAI API не затрагиваются.
- Production web сейчас настроен на `preDeployCommand=[bin/rails db:migrate]`: любой реальный deploy этой ветки немедленно запустит миграцию действующей PostgreSQL.
- У web нет постоянного volume, PostgreSQL 18 использует отдельный 5 GB `postgres-volume`; его актуальные backup и restore **не подтверждены**. Web media/avatars не выпускаем до решения durable storage.
- Имена переменных `RC_GROK_ENABLED` присутствуют, но `XAI_API_KEY` и `RC_GROK_PRODUCTION_APPROVED` в списке переменных web не обнаружены. Production paid AI нельзя считать включённым: код требует все три условия. Секреты не запрашивать и не публиковать.

## DoD перед первой production-выкладкой

1. Проверить все Rails CI, Security Audit и специальный `R1A PG18 deployed-baseline synthetic upgrade` **на точном SHA** релизной ветки. Старые CI RC051 ранее были SUCCESS, но не заменяют новые.
2. В Railway открыть Postgres → Backups, установить статус и дату последнего snapshot, оценить платную стоимость и иметь проверенный независимый путь restore. Не выполнять restore поверх действующего тома. Один зарегистрированный backup не равен проверенному восстановлению.
3. Зафиксировать текущий production browser baseline: вход владельца, consultation, текущая заявка и опубликованный экран; статус `SLEEPING` не доказывает доступность по HTTP.
4. Согласовать *именно* SHA выпуска, один миграционный номер, точный project/service/env, план отката к действующему web commit, режим xAI default-off, доступность и сохранность данных.
5. Лишь после отдельного согласия изменить Railway source/deploy: наблюдать pipeline, migration, smoke и сохранность существующих данных. Откат кода НЕ означает откат DB schema; `db:rollback` на production не запускать вслепую.

## Список последующих выпусков

- R1B — RC052/RC053 (owner intelligence/approved profiles) после отдельных миграций.
- R1C — RC053.2–RC055.0 (White Atlas, client intake, уведомления), с разделением UI и DB-зависимостей.
- R2 — RC055.1 (версионированные services, AI drafts и media); durable web storage как отдельный стоп-гейт для файлов.
- R3 — private AI Chat и C2.3 outbox из PR #79–81; G5/G6 обязательны для исторического backfill/replay, не для всех UI-исправлений.

Запрещено автоматическое применение всех 20 новых миграций из HEAD PR #81 за один релиз. Сохранить оригинальные рабочие деревья, PostgreSQL, media, backups и Railway.