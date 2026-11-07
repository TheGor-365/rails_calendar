# MASTER HANDOFF — Rails Calendar → AI Service Operating System
## Полная передача проекта новому ChatGPT-чату CAREER

**Дата:** 2026-11-07 (Asia/Yerevan)  
**Версия:** 2.0 / RC-022 checkpoint, подтверждение GitHub 07.11.2026.  
**Статус:** единый актуальный MASTER для следующего чата; заменяет в качестве точки входа `MASTER_RAILS_CALENDAR_2026-11-05(1).md` и `RAILS_CALENDAR_MASTER_HANDOFF_2026-11-06(3).md`. Эти старые файлы — исторические источники, а не актуальные инструкции.  
**Проект:** https://github.com/TheGor-365/rails_calendar  
**Текущий верхний продуктовый PR:** https://github.com/TheGor-365/rails_calendar/pull/23 — RC-022, Draft, не слит.  
**Ветка последней реализации:** `feature/rc022-reschedule-history-2026-11-07`  
**HEAD до добавления этого мастера:** `50f4949b34a9d373d99f10e56bad1782bddbc7d7`. Добавление этого файла создаёт новый документационный commit: **обязательно считай итоговый SHA с GitHub, не полагайся на предыдущий!**  
**Главный roadmap:** [RAILS_CALENDAR_DEVELOPMENT_ROADMAP_2026-11-07.md](RAILS_CALENDAR_DEVELOPMENT_ROADMAP_2026-11-07.md).  
**Решения:** [ADR-001 UTC](ADR001_UTC_TIMEZONE_CONTRACT_2026-11-07.md), [ADR-002 аудит/ресурсы](ADR002_RESCHEDULE_AUDIT_CAPACITY_2026-11-07.md).  
**Дополнительный Notion checkpoint:** https://www.notion.so/4102cdc8e76581eaa500d6aab39996a6 (писался предыдущим чатом, не заменяет код/CI).  
**Источник текущих фактов:** история обсуждения и скриншоты пользователя 05–07.11, GitHub PR #1–#23, файл roadmap и RC/ADR в текущем Draft-стеке, GitHub Actions, подтверждения пользователя в терминале. Не выводи новые факты из даты документа, проверяй live-источники.

---

# 0. ОБЯЗАТЕЛЬНО ПРОЧИТАТЬ И НАЧАТЬ ДЕЙСТВОВАТЬ

Ты — технический lead, QA/security инженер и операционный исполнитель существующего Ruby on Rails приложения `Rails Calendar`. **НЕ НАЧИНАЙ С НУЛЯ.** Используй подключённые плагины GitHub, Google Drive, при наличии Gmail, ClickUp и Notion. Всё, что можно обоснованно и безопасно сделать через плагины и GitHub Actions, делай автоматически в пределах данного обращения; не отправляй пользователя вручную на повторение уже сделанного. Сначала сверяй существующий статус и реальный HEAD. Результат: работающий и проверяемый продукт, не объём текста или количество PR.

**Первый рабочий блок в новом чате — без уточняющих вопросов:**

1. GitHub: проверь `main` SHA, PR #23 head/base/draft/CI/Security; прочитай этот master, roadmap, ADR-001, ADR-002, RC-021, RC-022, миграцию и тесты. Сверь наличие изменений после 07.11.2026 и исправь инвентарь, если появились новые подтверждённые факты.
2. **Прежде всего устрани технические P0-блокеры без риска для данных:** статический review security/session/CSRF/proxy, восстановительный SOP + безопасный скрипт проверки архива/изолированного restore, миграционный и rollback gate, проверка живого тестового CI. Там, где нет доступа к локальной базе или staging, подготовь полностью готовые самопроверяемые команды и явные критерии приёмки. Не выдавай `pg_restore --list` за реальный restore.
3. После P0 занимайся малым отдельным Draft PR: безопасность и конкурирующие редакторы (stale form / optimistic locking), конфиденциальность истории и ресурсная модель после согласования ADR-002. Дальнейший AI Intake — только после этой базы, без спонтанной архитектурной переписи.

**Операционный цикл:** факт с SHA/ссылкой → узкая задача и критерий → тест → минимальный патч → отдельная ветка/стек Draft PR → CI + Security на **одном итоговом SHA** → ручной visual QA, если нужен → checkpoint в repo/Notion/Drive → следующие 1–3 действия. Если произошёл провал CI, автоматически читай логи и чини до зелёного. Не заставляй пользователя читать повторные длинные планы вместо исполнения.

**Разрешено автоматически:** чтение GitHub/Drive, QA статическим анализом, написание безопасных тестов, документации, небольших функций, новых Draft PR, получение CI логов, исправление падений, обновление актуального roadmap/мастера/Notion, написание проверяемого staging SOP. Если есть доступ к изолированному тестовому окружению — запуск тестов на фикстурах. **Письма/публикации/эксплуатационные изменения делать только когда конкретный адресат, содержание и результат уже однозначно согласованы.**

**Запрещено без отдельного подтверждённого release gate:** merge или force-push, деплой на Railway/production, платные ресурсы, миграции в реальную локальную/боевую БД, удаления/откаты настоящих записей, уничтожение или перезапись резервных копий, необратимое уничтожение документов и репозиториев, сторонние отправки клиентам, запуск платежей, раскрытие credentials. Пользователь дал широкое разрешение на автоматическую работу, **но не разрешение рисковать клиентскими данными и production**. Процесс на `:3005` может принадлежать старой сессии — никогда не делай `pkill ruby`, `killall rails`, `rails db:drop`, `git reset --hard`. Любой Stop — только конкретно подтверждённый процесс проекта или действие пользователя.

## 0.1. Формат взаимодействия
- Русский язык; технический Ruby/Rails-словарь, предельно конкретно, 1–3 действий от пользователя максимум до следующего screenshot/log.
- Без повторной установки Rails/GitHub/KYC, создания уже существующего проекта и фиктивных работ. Отмечай `выполнено кодом`, `CI PASS`, `визуально принято`, `локально применено`, `staging PASS`, `production deployed` как **разные** уровни.
- На скриншоте считать фактом только то, что видно; не приписывать нажатию Cancel/Submit статус, если показана лишь открытая форма.
- Не запрашивать пароли, токены, DATABASE_URL, ключи, подписи и приватные архивы.

# 1. О ПРОДУКТЕ И ГРАНИЦАХ

Проект — существующий учебный Rails Calendar, развиваемый в подтверждённую систему оказания цифровых услуг и обслуживания консультаций. Начальная ниша владельца: небольшие Ruby on Rails багфиксы, CRUD, формы, API/PostgreSQL, тесты, внедрения. Календарь — интерфейс расписания, **не** готовый SaaS/CRM, не доказательство платных заказов и не полноценный многопользовательский booking engine. Долгосрочно возможно узкое AI Intake: структурированный запрос клиента → интервью → проверенная версия ТЗ → оценка и ручное согласование → подтверждённый scope/milestone → календарь и аудит. AI не имеет права автоматически обещать цену, срок, оплату или клиентское согласие.

Среда разработки пользователя:
- Linux Mint, проект локально в `~/rails_calendar_3005`, адрес `http://127.0.0.1:3005`; соседние Rails приложения используют другие порты и их нельзя останавливать.
- На последних Draft-ветках Ruby **3.4.12**, Rails **8.1.4.1**, PostgreSQL **16.11** для локальной БД, Puma 8, Turbo/Stimulus, Bootstrap/Sass/esbuild, simple_calendar. Не ориентируйся на старый Ruby 3.1.2 / Rails 7.0.4.1 из `main`.
- БД разработки `ruby_calendar`. Тестовая и staging БД должны быть физически отделены, не переназначать `DATABASE_URL` вслепую.
- Путь архива, созданного владельцем и проверенного по чтению:
  `$HOME/.local/share/rails_calendar/backups/ruby_calendar_pre_rc018_2026-11-07.dump`, права `0600`, размер в показанном терминале около 5.4 КБ. Архив создал **pg_dump 18.6**, прочитался только **/usr/lib/postgresql/18/bin/pg_restore**, хотя сервер БД PostgreSQL 16.11. Команда `pg_restore --list` и `pg_restore --file=/dev/null` дала `BACKUP_CHECK=PASS`. **Полное восстановление в отдельную БД НЕ ВЫПОЛНЕНО.**
- В момент предыдущих переключений были локально изменён `db/schema.rb` (после RC-018 миграции), неотслеживаемые `.tool-versions` и `vendor/bundle/`. Позже пользователь показал работающий RC-020 UX, **последний локальный HEAD неизвестен**. Не предполагай, что там RC-022; узнай `git status --short --branch` без reset и без автопереключения.
- Локальная RC-018 миграция `CreateAdminLoginWindows` применена пользователем; `AdminLoginWindow.table_exists? = true`; кодом проверено `[false,false,false,false,false,true]` на шести попытках синтетического IP. Это не live HTTP 429.
- Сохранённые локальные консультации по последним проверкам:
  * `#3`: `RC-P0 QA — DELETE AFTER TEST`, 12 Nov 2026 09:00–09:30 UTC;
  * `#4`: `Third`, 13 Nov 2026 11:00–12:40 UTC.
  Обе считаются **данными владельца, не удалять для тестирования**. Исходная `#2` удалена по ошибке; пользователь прямо сказал, что она была ненужной демонстрацией и восстановления не требует. Ни одна новая миграция RC-022 в локальную БД не подтверждена.

# 2. САМЫЙ ВАЖНЫЙ СТАТУС GIT / PR

GitHub repo: https://github.com/TheGor-365/rails_calendar

**Подтверждено 07.11.2026:** `main` SHA `f6c8df5f2b9531fa9054ff96a0300256ca7be47f` (старый код от 2023-01-20). **Ни один** из 22 PR в списке ниже не слит; все оставались **open + Draft**. Стек глубоко вложенный; разные PR сравниваются с предшествующими ветками, а не напрямую с `main`. Не пытайся merge всех сразу. Сначала запланируй review полноты ancestry, gate, безопасную стратегию последующего объединения. Не переписывай историю и не закрывай чужие PR автоматически. `PR #4` — явно **SUPERSEDED / DO NOT MERGE**. `PR #15` не найден в стеке Rails Calendar — **не считать его частью этапов**.

## 2.1. Матрица сделанного по фазам и фактам

| RC | PR | Работа | Текущее доказательство/остаток |
|---|---:|---|---|
| RC-001 | [#1](https://github.com/TheGor-365/rails_calendar/pull/1) | Базовые запросы месяца, проверки Consultation и CI | Код в Draft; итоговый release нет |
| RC-002 | [#2](https://github.com/TheGor-365/rails_calendar/pull/2) | ENV-администратор, session ACL на создание/изменение/удаление | Тесты + ручной CRUD; не клиентские роли |
| RC-003 | [#3](https://github.com/TheGor-365/rails_calendar/pull/3) | Ruby 3.4.12 / Rails 8.1.4.1 + зависимости | CI выполнен, отдельный runtime upgrade не в main |
| дубль | [#4](https://github.com/TheGor-365/rails_calendar/pull/4) | Альтернативный RC-003 | **SUPERSEDED: НЕ MERGE И НЕ ВОЗРОЖДАТЬ** |
| RC-006 | [#5](https://github.com/TheGor-365/rails_calendar/pull/5) | Начальная защита логина и HTTPS policy | Позднее усилена RC-018/021; staging proxy gate |
| RC-004 | [#6](https://github.com/TheGor-365/rails_calendar/pull/6) | Доступные responsive формы/календарь | Код/CI, release QA объединённого стека ещё нет |
| RC-007 | [#7](https://github.com/TheGor-365/rails_calendar/pull/7) | Minimal UI Slate & Tide, серверные границы дат | Код и тесты |
| RC-008 | [#8](https://github.com/TheGor-365/rails_calendar/pull/8) | 24-часовой день, ручное планирование администратором | Код/CI и скриншоты |
| RC-009 | [#9](https://github.com/TheGor-365/rails_calendar/pull/9) | Компактная плотная часовая сетка | Код/CI |
| RC-010 | [#10](https://github.com/TheGor-365/rails_calendar/pull/10) | Непрерывные блоки 24-часовых интервалов, overlap lanes, детали часа | Код/CI, скриншоты многочасового блока |
| RC-011 | [#11](https://github.com/TheGor-365/rails_calendar/pull/11) | Старт `:3005`, NameError Zeitwerk, deep links, Month/Day/Hour/Detail, разделение index/show | NameError устранён; CI/Security; подтверждения пользователя |
| RC-012 | [#12](https://github.com/TheGor-365/rails_calendar/pull/12) | Месяц на мобильном 7 колонок, компактные ячейки + список событий | 430 px скриншот, переходы работают |
| RC-013 | [#13](https://github.com/TheGor-365/rails_calendar/pull/13) | Стилевые иконки с видимой подписью, touch/focus | Код, Chrome, скриншоты |
| RC-014 | [#14](https://github.com/TheGor-365/rails_calendar/pull/14) | Fixed dock `Month | Today | + | Records | Admin`, max 430px/safe-area, центрирование; действия в одну строку | Сначала был CSS-cache/stale build, после RC-014b пользователь подтвердил красивый fixed nav на 430 px. QA на 320/390/keyboard ещё не до конца принято |
| RC-015 | [#16](https://github.com/TheGor-365/rails_calendar/pull/16) | HH:MM без секунд, валидация, legacy seconds, Delete с ID/названием/датой | Скриншоты создания #4 и формы, CI+Security; удаление чужих записей запрещено |
| RC-016 | [#17](https://github.com/TheGor-365/rails_calendar/pull/17) | Explicit UTC, DST/midnight regressions, session expiry | CI/Security; локальный/клиентский timezone не решён |
| RC-017 | [#18](https://github.com/TheGor-365/rails_calendar/pull/18) | Приватный production default, явный `RAILS_CALENDAR_PUBLIC_DEMO_MODE=true` | CI/Security; инкогнито screenshot редиректа на логин. Нет row ACL |
| RC-018 | [#19](https://github.com/TheGor-365/rails_calendar/pull/19) | PostgreSQL shared HMAC-IP throttle, атомарные попытки, 429/503 | CI/Security; локальная миграция и 6-й вызов модели PASS, реальный browser HTTP 429/proxy staging не принят |
| RC-019 | [#20](https://github.com/TheGor-365/rails_calendar/pull/20) | Точная длительность, title/date/status фильтры, пагинация, responsive | CI/Security; десктоп screenshot `#4: 1h40m` и фильтры title/13 Nov PASS; mobile/Clear ещё требуется UI QA |
| RC-020 | [#21](https://github.com/TheGor-365/rails_calendar/pull/21) | Неблокирующие collision warnings, Reschedule link на Edit | CI/Security; пользователь нажал Reschedule #4 и увидел предзаполненные 11:00–12:40 UTC. Сохранение/Cancel не подтверждено; пересечения между #3/#4 нет |
| RC-021 | [#22](https://github.com/TheGor-365/rails_calendar/pull/22) | P0 HTTP-тесты login 429/503, logout/admin ACL и Selenium Cancel на фикстуре; restore SOP | **113 тестов / 881 проверка, CI+Security SUCCESS**. Test pass **не заменяет** реальный staging restore, cookie/CSRF/proxy QA |
| RC-022 | [#23](https://github.com/TheGor-365/rails_calendar/pull/23) | Транзакционная история переносов: изменённые UTC интервалы, причина, роль admin, audit UI | **123 теста / 982 проверки; CI+Security SUCCESS** на `50f4949`. Миграция только в CI, НЕ применена к локальной или production БД; ручной UI и owner policy approval открыты |

**Точное последнее CI до документационного коммита мастера:** [Rails CI run 42388950607](https://github.com/TheGor-365/rails_calendar/actions/runs/42388950607) — SUCCESS: **103 Rails tests/709 assertions** + **20 Chrome tests/273 assertions** = **123 теста/982 проверки, 0 failures/errors/skips**. [Security Audit 42388950460](https://github.com/TheGor-365/rails_calendar/actions/runs/42388950460) — SUCCESS, тот же SHA `50f4949b34a9d373d99f10e56bad1782bddbc7d7`. Добавление текущего файла изменяет SHA; новые GitHub Actions необходимо перепроверить. **Не писать, что прошёл финальный SHA, пока не видно успешного run именно на нём.**

## 2.2. Важные развилки и инциденты из чата

1. Сначала `PagesController#day` падал `NameError uninitialized constant PagesController::Calendar`. После правильной структуры `Calendar::DayEventLayout` и безопасного launcher глубокие ссылки стали работать. Не восстановить этот баг.
2. На месяце дата и событие должны вести к дню/событию, а не быть только декоративными карточками; `Today` и `Today ·24h` ведут к 24-часовому виду. `Consultations` — индекс записей/поиск; `show` — конкретный объект и admin-действия; не объединять обратно в два почти одинаковых пустых экрана.
3. Мобильная версия **не может иметь меньше управления, чем десктоп**. Переходы и события доступны на 320/390/430; иконки Bootstrap Icons в стиле Slate & Tide, подписи видимы, dock fixed, пять равных ячеек, центральная выпуклая +, safe-area, content bottom padding. На раннем этапе старый CSS сделал dock плоской полосой, поэтому перед заявлениями о UI PASS проверять реально собранные CSS/JS, browser cache, scroll, fixed position.
4. Секунды во вводе не нужны; визуально `datetime-local` HH:MM, сервер ограничивает изменённые timestamps целыми минутами, **но legacy seconds при edit текста должны сохраняться**.
5. Пользователь протестировал создание `#3`, edit, удаление, затем по ошибке удалил `#2`; решил не восстанавливать, потому что это была демонстрация. Никогда не удалять `#3` или `#4` «для smoke-test». Selenium Cancel тестирует только **изолированную fixture**.
6. Пользователь проверил backup: `pg_dump --version` показывал 16.11 в PATH, фактически архив создан pg_dump 18.6 из среды; pg_restore 16.11 не понимает custom header 1.16, pg_restore 18.6 понимает; `BACKUP_CHECK=PASS` означает чтение, а не проверенное восстановление.
7. По `AdminLoginWindow.throttled?` локальный вывод шестого вызова `false,false,false,false,false,true`; CI HTTP-тесты тоже проходят. Не объявлять actual browser/proxy 429 доказанным.
8. Скриншоты пользователя `/consultations/4`: длительность `1 h 40 min`, 13 Nov 2026 11:00–12:40 UTC. Поиск `Third` вернул одну запись, фильтр UTC 13 Nov вернул одну запись. `Reschedule` открыл `/consultations/4/edit#consultation_start_time` с исходными датами. Ни реального переноса, ни audit history на локальной БД он **ещё не демонстрировал**.

# 3. RC-022 — ТЕХНИЧЕСКИЙ КОНТРАКТ И ПОДВОДНЫЕ КАМНИ

Источник: [RC022_RESCHEDULE_HISTORY_2026-11-07.md](RC022_RESCHEDULE_HISTORY_2026-11-07.md), [ADR-002](ADR002_RESCHEDULE_AUDIT_CAPACITY_2026-11-07.md); смотри реальные файлы на текущем HEAD.

- Миграция `db/migrate/20261107193000_create_consultation_reschedule_events.rb`: добавляет `consultation_reschedule_events`, без переписывания `consultations`. Поля: consultation_id, old_start_time, old_end_time, new_start_time, new_end_time, actor_label, reason, created_at + индекс. **Никакого cascade DELETE/FK**, потому что существующие consultation ещё физически удаляются, а audit snapshot должен сохраняться. Privacy retention/erasure остаётся будущим решением.
- Модель `ConsultationRescheduleEvent` проверяет обязательные поля, длины, факт изменения; `readonly?` для persisted защищает через ActiveRecord, но НЕ от прямого привилегированного SQL, `update_columns` и изменения исходника. Это **не** forensic tamper-proof audit.
- Сервис `Consultations::Reschedule` делает `with_lock`, сравнивает фактические start/end с новыми, на изменении требует `reschedule_reason` 1–500 chars; сам назначает actor_label `administrator`, не доверяет actor из формы. `consultation.save` и создание audit snapshot в одной транзакции. Некорректные поля → HTTP 422 без изменения и без audit; title/description-only edit не требует reason. Legacy unchanged-minute handling работает до вызова сервиса.
- Контроллер `ConsultationsController#show` отдаёт 20 последних записей истории только admin. Guest не видит ни reason, ни history. Формы доступны только admin. Причина фильтруется в Rails parameter logging, но физически хранится в БД/backup; не писать чувствительную PII в reason.
- На форме `_form.html.erb` поле причины появляется при редактировании; в `show.html.erb` — адаптивная история с UTC old/new, reason, actor. У браузера 320/390/430 Chrome regression на dock + audit/reason.
- **Известный остаточный риск:** блокировка DB-строки обеспечивает честный persisted before/after в каждой транзакции, но НЕ решает stale-form overwrite в двух вкладках. Нужен optimistic locking / If-Match / version check и наглядная conflict UX перед multi-actor use.
- **Actor** — метка общей роли администратора, а не человеческая личность. **Client accepted/confirmed** в системе не существует; не интерпретировать сохранение администратором как согласие клиента.
- Нынешний `destroy` физически удаляет consultation; audit snapshot остаётся недоступным из исчезнувшего show, но в БД; retention и право на удаление ещё не разработаны.

# 4. ЧТО ОСТАЛОСЬ НЕ ЗАКРЫТО (ЧЁТКИЙ BACKLOG)

## P0 / блокирует выпуск и реальных клиентов

| Приоритет | Блокер | Сделано | Что именно ещё нужно |
|---|---|---|---|
| P0 | Схема/восстановление | RC-018 локальная миграция + архив читается pg_restore 18.6; RC-022 миграция CI PASS | **Реальный restore в новой изолированной staging DB**, контроль числа строк/ID/schema, тест миграции RC-022 и rollback на копии, файл SOP и доказательства |
| P0 | Стек Draft PR | Все PR открыты и CI отрабатывает на ветках | Review ancestry #1→#23 без #4 и посторонних, угрозы конфликтов и статусы финальных SHA, затем *отдельно разрешённое* объединение |
| P0 | HTTPS/session/CSRF | ENV admin, ACL, security tests, forced SSL policy | Реальная reverse-proxy TLS termination, Secure/SameSite/HttpOnly cookies, CSRF отрицательные тесты в staging, 8h expiry, logout/credential rotation |
| P0 | IP rate-limiter | DB-backed HMAC, модель threshold, CI HTTP tests | Реальный HTTP 429/503 и несколько инстансов/прокси, trusted proxies vs X-Forwarded-For spoofing, NAT, cleanup job `AdminLoginWindow.prune_expired!` мониторинг |
| P0 | Клиентская приватность | Production private-by-default + owner incognito PASS | Любые реальные client records **нельзя** в public-demo DB; User/tenant/ownership, per-row ACL, client portal/capabilities и аудит |
| P0 | Необратимое Delete | Точный dialog, Selenium Cancel fixture | Решить soft-delete/cancellation + audit retention; **не трогать #3/#4**; перед release проверять isolated QA |
| P0 | Конкурентные изменения | Атомарный RC-022 audit, с row lock | Stale-form protection, concurrency/optimistic lock и контроль конфликтов сохранения |
| P0 | UI/accessibility финальный | Chrome автоматизация 320/390/430, некоторые owner screenshots PASS | Владелец не принимал все экраны на 320px/390px, keyboard/focus, no-JS, cache/hard reload, empty states и mobile search/Clear |
| P0 | Policy/retention | Audit snapshot в Draft | Политика хранения/удаления истории, доступ администратора, централизованный журнал, защита от привилегированного SQL при необходимости |
| P0 | Railway | Никакого подтверждённого Rails Calendar staging/production релиза | Cost review, конфигурация, DB backup/recovery, после explicit approval отдельный staging smoke; не спутать с другими Railway приложениями владельца |

## P1 / полноценный календарь

1. **ADR-002 сейчас частично проектный.** Пересечения `[start,end)` в RC-020 предупреждают, но не блокируют. Для capacity понадобятся `resource_id`, модель исполнителя/комнаты/команды, capacity count (возможна >1), статусы `draft/confirmed/cancelled` и проверка двойного бронирования транзакционно. Не вводи hard-rejection до выбора бизнес-правил. Две заявки разных исполнителей не конфликтуют. Точная граница end==start не конфликтует.
2. История переносов на локальном/staging UI не принята, миграция не проведена вне CI; нужно безопасное применение после backup, smoke, проверка старых полей, отказа без reason, audit и сохранения записей. Никаких тестовых созданий/удалений в пользовательской БД.
3. Утверждение/отклонение/перенос клиента, cancellation, no-show, повторное бронирование и напоминания — **не реализовано** как завершённый бизнес-цикл.
4. Локальные и клиентские часовые пояса: приложение намеренно отображает UTC, для Armenia UTC+4 это часто непривычно; выбор IANA zone, DST/23–25 часов и двойная подпись — отдельный UX ADR. Исторические timestamps не переинтерпретировать.
5. UX: убрать дубли в формах/страницах, полезная пустая страница, логичная navigation, фильтры, нет декоративных dead-ends, контроль узких экранов.
6. Исполнитель/клиент не имеет отдельных учётных записей; не выдавать единый admin login за готовое B2B SaaS решение.

## P2 / AI Intake — только после P0/P1 domain boundary

Сначала ADR и schema-contract на `Identity/User`, `ClientRequest`, `Conversation/Message`, `ProfessionalPlaybookVersion`, `SpecVersion`, `Estimate`, `Approval`, `Project`, `Milestone`, `Task`, `CalendarEvent`, `Notification`, `AuditEvent`. **Это предложения, не реализованные таблицы.** Первый узкий vertical — Rails bug-fix/CRUD/API. AI интервью + schema-valid JSON + versioned draft spec; человек подтверждает стоимость/сроки, клиент утверждает конкретную immutable версию scope. Никаких автоматических платежей, утверждений, внешних сообщений, создания «реальных заказов» из демо, массовой генерации контента. Нужны prompt-injection boundaries, квоты/лимиты ИИ, retry/idempotency, ownership, журнал согласований.

## P3 / API, Capacitor, web-mobile

Rails+PostgreSQL остаётся system of record; потом versioned `/api/v1`, Vite frontend entry, Capacitor Android/iOS, мобильная parity и проверка платформ/стоимости. Нельзя просто упаковать ERB/Turbo в Capacitor `webDir` и назвать нативным приложением.

## P4 / staging, RU/EN portfolio, leads

После release gate — отдельный staging и скриншоты, CI/коммиты/ограничения и правдивый кейс (учебный/demo). Коммерческая ценность — квалифицированные запросы и оплаченные заказы, а не созданные ветки; не выдавать календарь за реальный платный заказ. Не деплоить в чужой Railway проект.

# 5. ПЛАН СЛЕДУЮЩЕГО ЧАТА: 1–3 КОНКРЕТНЫХ РАБОТЫ

**Приоритет не «добавить ещё таблицы», а закрыть риски перед ростом.**

**Спринт S0 — без действий пользователя, максимум автоматики:**

1. Выполни live GitHub readback: `main`, PR #23 и его parent #22/#21, дорожную карту, последние CI/Security на **текущем** HEAD (включая этот файл). Если CI красный — читай job logs и исправляй. Обозначь настоящие нерешённые замечания из PR review/Checks, зафиксируй checkpoint.
2. Прочитай `db/migrate/20261107193000_create_consultation_reschedule_events.rb`, `Consultations::Reschedule`, `AdminAuthentication`, `AdminLoginWindow`, session/production config, тесты. Проведи **read-only review** связности: data-loss/deletion, stale form, audit immutability, tenancy, PII/log, CSRF/IP proxy. Создай Draft PR на *безопасное* изменение (например, улучшенная невыполняемая по умолчанию процедура восстановления + fail-closed проверки и отдельные тесты). Не делай миграций у пользователя автоматически.
3. Подготовь reproducible **проверяемый staging restore план и CLI-команду/скрипт с dry-run guard**: проверь pg_restore 18.6, checksum/TOC, имя `new empty isolated DB`, запрет цельных имён `ruby_calendar`/`ruby_calendar_test`, отдельные креды/сервер и abort if exists. Но **не выполнять restore/migrate** без подтверждения изолированной инфраструктуры. Проверить возможность staging через доступные ресурсы/плагины; не создавать платные сервисы автоматически.

**Спринт S1 — после доказанного staging restore и owner gate:**

- Прогон миграции RC-022 только на **копии**, проверка count/IDs/данных, обратный сценарий rollback на отдельной копии, CI/staging smoke, secrets/config. После принятия — отдельный план локального применения (с сохранением владельца `db/schema.rb`).
- Ручной пользовательский тест **без сохранения**: открыть в приложении `#4` → Reschedule → проверить исходные 11:00–12:40 → Cancel; затем передать только скриншот. Для проверки настоящего audit использовать только явно разрешённую **новую временную запись в изолированном staging**, не #3/#4.
- Принять или отклонить ADR-002: capacity per resource, confirmed status, отмена/перенос и client approval. До решения — только advisory и history технического сохранения.

**Спринт S2 — после S1:**
- Отдельный узкий PR на защиту устаревших вкладок: optimistic locking или эквивалент (предпочтительно стандартизированный Rails `lock_version` с миграцией и graceful conflict UI). Проверить, что два администратора не перетирают друг другу изменения; reason/audit в конфликте не создаётся. Тесты на два параллельных запроса.
- После policy approval — ресурсная модель, статусы бронирования и race-safe проверка capacity, не blanket «одна запись во всём календаре».
- Переход к AI Intake по фазе C только после domain/security baseline и реальной UI acceptance.

**Что запросить у пользователя (только когда нужно):** один безопасный вывод `git status --short --branch` / `git rev-parse --short HEAD` или один screenshot, статус staging/доступность инфраструктуры/разрешение на расход. Не заставляй пользователя возвращаться к уже пройденным KYC/настройкам/исполнению тестов, которые доступный CI может сделать за него.

# 6. ПРАКТИКА РАБОТЫ С GIT/RAILS

Пример **только read-only** локальной проверки (выполняет владелец, если у чата нет локального компьютера):

```bash
cd ~/rails_calendar_3005
git status --short --branch
git rev-parse --short HEAD
ss -ltnp '( sport = :3005 )'
```

Для возможного перехода на новую ветку: перед ним фиксируй статус и необработанные файлы; не делай `git restore` / `git clean` / `reset --hard`. После остановки **только собственного процесса проекта на :3005** выполняй `git fetch origin` и безопасное `git switch --track ...`. Для старого `db/schema.rb` нужна отдельная сверка diff/backup; не позволять автоматически перезаписать локальные изменения. `bin/run-calendar-3005` делает build CSS/JS и проверяет port; при `Port 3005 is occupied` не поднимай второй экземпляр, уточни владельца сокета.

**Никогда не вставлять локальный `DATABASE_URL` или пароль в chat.** Команды теста должны явно указывать `RAILS_ENV=test` и чистую тестовую БД; если нельзя гарантировать изоляцию — не выполнять. `env -u DATABASE_URL` может быть полезен для пользовательского локального dev, но не заменяет аудит `config/database.yml`.

CI: Rails model/controller, Chrome system 320/390/430, bundler/npm security, GitHub Actions CI/Security. Поскольку после каждого документационного коммита HEAD меняется, каждый итоговый PASS сверяй по **exact SHA**, а не по старому зелёному запуску. Не объявлять локальный успех на основании CI браузера.

# 7. УПРАВЛЕНИЕ РЕПОЗИТОРИЕМ, ДОКУМЕНТАМИ И СЕКРЕТАМИ

**Приоритет правды:** текущий GitHub HEAD + CI/PR → пользовательский фактический тест → официальный ADR/roadmap → исторический master. Если источники противоречат, записать расхождение с датой, не выдумывать.

**Проверка старых мастеров на 07.11.2026:** в корне и `docs/` актуальной ветки RC-022 находятся **roadmap + ADR + RC-чеклисты, но нет ранее загруженного `MASTER_RAILS_CALENDAR_2026-11-05...` или `RAILS_CALENDAR_MASTER_HANDOFF_2026-11-06...`**. Точечный поиск Google Drive по `RAILS_CALENDAR` / `MASTER_RAILS_CALENDAR` / `Calendar` не нашёл таких файлов. Старые 05/06.11 документы есть среди ранее приложенных conversation/Library-материалов; не следует объявлять их удалёнными из GitHub/Drive. Нельзя удалять `docs/RC010...`, `docs/RC011...`, ADR, roadmap: это исторические доказательства и работающие ссылки, не «неактуальный мусор». **Этот документ — текущий и единственный рекомендуемый входной мастер; устаревшие остаются архивным контекстом до обнаружения реального дубликата на конкретном сервисе.**

На GitHub хранить Markdown с безопасными статусами, тестовыми фактами, ссылки на CI/PR; в Drive — актуальный markdown в отдельной рабочей папке, не в `ИП` с приватными ID/KYC. На Notion — короткие checkpoint. Изменения в одном чате не синхронизируются автоматически с другим: записывай источник, дату, exact SHA и проверенное размещение. При создании следующего мастера обновляй указатель здесь и в roadmap, но не удаляй старые docs без проверки inbound links.

**Секреты/PII:** не копировать реальные consultation titles/descriptions в публичную документацию, если они не синтетические; архивы БД, .env, креды, клиентские запросы и банковские сведения не публиковать в GitHub, Notion, публичном Drive. Не отправлять резервную копию, пароли, токены, ключи/подписи в чат/плагины. Приложение пока не соответствует реальной multi-client изоляции.

# 8. ССЫЛКИ И CHECKPOINT

- Repository: https://github.com/TheGor-365/rails_calendar
- Последний Draft PR #23 RC-022: https://github.com/TheGor-365/rails_calendar/pull/23
- P0 предыдущий Draft PR #22: https://github.com/TheGor-365/rails_calendar/pull/22
- RC-020 #21: https://github.com/TheGor-365/rails_calendar/pull/21
- RC-019 #20: https://github.com/TheGor-365/rails_calendar/pull/20
- RC-018 #19: https://github.com/TheGor-365/rails_calendar/pull/19
- RC-017 #18: https://github.com/TheGor-365/rails_calendar/pull/18
- RC-014 #14: https://github.com/TheGor-365/rails_calendar/pull/14
- Не сливать дубль #4: https://github.com/TheGor-365/rails_calendar/pull/4
- Roadmap: https://github.com/TheGor-365/rails_calendar/blob/feature/rc022-reschedule-history-2026-11-07/docs/RAILS_CALENDAR_DEVELOPMENT_ROADMAP_2026-11-07.md
- RC-021 security/restore: https://github.com/TheGor-365/rails_calendar/blob/feature/rc022-reschedule-history-2026-11-07/docs/RC021_P0_SECURITY_RECOVERY_GATE_2026-11-07.md
- RC-022 audit: https://github.com/TheGor-365/rails_calendar/blob/feature/rc022-reschedule-history-2026-11-07/docs/RC022_RESCHEDULE_HISTORY_2026-11-07.md
- ADR-002: https://github.com/TheGor-365/rails_calendar/blob/feature/rc022-reschedule-history-2026-11-07/docs/ADR002_RESCHEDULE_AUDIT_CAPACITY_2026-11-07.md
- Последний код+документация SHA до этого файла: `50f4949b34a9d373d99f10e56bad1782bddbc7d7`, [CI](https://github.com/TheGor-365/rails_calendar/actions/runs/42388950607), [Security](https://github.com/TheGor-365/rails_calendar/actions/runs/42388950460).
- Notion checkpoint: https://www.notion.so/4102cdc8e76581eaa500d6aab39996a6

# 9. ПОСЛЕДНЯЯ ОПЕРАЦИОННАЯ ЗАПИСЬ

**Проверено:** код RC-001–022 накоплен в Draft-стеке; PR #23 CI+Security PASS, 123 теста/982 проверки на `50f4949`; пользователь подтвердил desktop Reschedule на #4; RC-018 PostgreSQL таблица локально существует; архив pg_dump 18 читается pg_restore 18.  
**Сделано этим поколением чатов:** roadmap/ADR/RC docs, мобильная навигация, безопасность admin, calendar CRUD, поиск, advisory overlaps, версия истории переносов, регрессионные тесты, GitHub PR, Notion checkpoints.  
**Не сделано:** merge, безопасный staging restore, продакшен-деплой, применение RC-022 миграции у пользователя, row ACL, resource capacity policy, названные реальные акторы, клиентские согласования, аудит на локальном UI, подтверждённые платежи/клиенты/реальный SaaS.  
**Блокер №1:** отсутствие проверенного isolated restore и миграционного gate.  
**Блокер №2:** HTTPS/proxy/cookie/CSRF и client ownership.  
**Блокер №3:** stale-form edit/retention/resource policy.  
**Первые 1–3 действия нового чата:** (1) проверка HEAD+CI+security, (2) автоматический read-only security/staging gate review и Draft тесты/SOP, (3) при отсутствии локальной/staging-среды — одно конкретное безопасное действие владельца, а не длинный общий опрос.

> Этот мастер не даёт права на необратимые операции. Он даёт новому чату всю техническую и продуктовую картину, чтобы **сразу исполнять следующий безопасный этап**.
