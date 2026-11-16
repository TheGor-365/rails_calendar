module OwnerAi
  # Deterministic, FREE owner navigation. Supports natural fragments, synonyms,
  # spelling mistakes and owner-owned service titles without model calls.
  # Never turns input into arbitrary controller/action, URL or raw SQL.
  class Navigator
    Page = Struct.new(:key, :label, :path, :aliases, keyword_init: true)
    Result = Struct.new(:status, :target, :candidates, keyword_init: true)

    # Route helpers are explicit allowlists, not taken from user-supplied text.
    # Dynamic records below are separately scoped to the signed-in workspace.
    DESTINATIONS = {
      "workspace" => {
        path: :workspace_path,
        aliases: %w[workspace dashboard home start] +
          ["рабочая область", "работа", "пространство", "главная рабочая", "панель управления", "главное меню", "начало", "dashboard", "աշխատատարածք"]
      },
      "cabinet" => {
        path: :owner_cabinet_path,
        aliases: ["кабинет", "мой кабинет", "профиль", "личный кабинет", "аккаунт", "учетная запись", "настройки профиля",
                  "мой аккаунт", "cabinet", "profile", "account", "personal", "mi cuenta", "աշխատասենյակ"]
      },
      "services" => {
        path: :owner_services_path,
        aliases: ["услуги", "услуг", "услуга", "мои услуги", "каталог", "каталог услуг", "карточки услуг", "товары",
                  "сервисы", "сервис", "предложения", "прайс", "service", "services", "offers", "catalog",
                  "catalogue", "servicios", "ծառայություններ"]
      },
      "service_new" => {
        path: :new_owner_service_path,
        aliases: ["новая услуга", "добавить услугу", "создать услугу", "новая карточка", "добавить сервис",
                  "create service", "new service", "add service", "nuevo servicio"]
      },
      "catalogue_ai" => {
        path: :owner_catalogue_ai_path,
        aliases: ["аудит каталога", "аудит услуг", "проверка услуг", "ии ревизор", "ai ревизор", "ревизор",
                  "ии каталог", "каталог ии", "ии помощник каталога", "ai catalogue", "catalog ai",
                  "service audit", "audit services", "copilot каталога"]
      },
      "practice" => {
        path: :owner_practice_path,
        aliases: ["практика", "моя практика", "опыт", "профессиональная практика", "резюме", "опыт работы",
                  "experience", "practice", "professional", "experiencia", "փորձ"]
      },
      "capabilities" => {
        path: :owner_capabilities_path,
        aliases: ["навыки", "компетенции", "умения", "технологии", "стек", "профессиональные навыки",
                  "skills", "capabilities", "tech stack", "competencies", "habilidades"]
      },
      "interview" => {
        path: :owner_setup_path,
        aliases: ["интервью", "знакомство с ии", "онбординг", "анкета исполнителя", "вопросы исполнителю",
                  "сбор информации", "обо мне", "setup", "interview", "onboarding", "questionnaire"]
      },
      "profile_review" => {
        path: :owner_setup_review_path,
        aliases: ["подтверждение профиля", "проверка профиля", "утвердить профиль", "проверить анкету",
                  "profile review", "review profile"]
      },
      "spending" => {
        path: :owner_ai_activity_path,
        aliases: ["расходы", "траты", "стоимость ии", "бюджет", "лимит ии", "журнал расходов",
                  "история ии", "счета ии", "spending", "billing", "cost", "expenses", "gastos"]
      },
      "assistant" => {
        path: :owner_ai_assistant_path,
        aliases: ["помощник", "ии помощник", "ассистент", "чат", "ии чат", "генератор", "генерация текстов",
                  "assistant", "ai assistant", "copilot", "chat", "asistente", "օգնական"]
      },
      "calendar" => {
        path: :root_path,
        aliases: ["календарь", "расписание", "планировщик", "записи", "сетка календаря",
                  "calendar", "schedule", "planner", "calendario", "օրացույց"]
      },
      "today" => {
        path: :calendar_day_path,
        aliases: ["сегодня", "сегодняшний день", "день", "дневной календарь", "план дня", "расписание сегодня",
                  "today", "day view", "today schedule", "hoy", "այսօր"]
      },
      "hour" => {
        path: :calendar_hour_path,
        aliases: ["час", "по часам", "почасовой", "часовой вид", "время", "расписание по часам",
                  "hour", "hourly", "time slots", "vista hora"]
      },
      "consultations" => {
        path: :consultations_path,
        aliases: ["консультации", "встречи", "созвоны", "звонки", "приемы", "консультация",
                  "consultations", "meetings", "calls", "consultas", "խորհրդատվություն"]
      },
      "consultation_new" => {
        path: :new_consultation_path,
        aliases: ["новая консультация", "записать встречу", "создать консультацию",
                  "new consultation", "book meeting"]
      },
      "public_services" => {
        path: :services_path,
        aliases: ["витрина", "публичные услуги", "сайт услуг", "сайт", "лендинг услуг",
                  "public services", "showcase", "витрина услуг"]
      }
    }.freeze

    ADMIN_DESTINATIONS = {
      "inbox" => {
        path: :admin_project_intakes_path,
        aliases: ["входящие заявки", "заявки", "обращения клиентов", "запросы клиентов",
                  "инбокс", "inbox", "inquiries", "requests", "leads", "solicitudes"]
      }
    }.freeze

    STOP_WORDS = %w[
      открой открыть открывай покажи показывай перейти перейди переход
      отведи веди меня пожалуйста хочу хочу_на нужно хочу_в
      зайди зайти запусти запустить иди по покажи_мне
      мне мой мою мои мое этот эту это страницу страница раздел раздела
      в во на к ко по для с со о об из и или где там тут нужно нужны надо хочу
      вкладку вкладка здесь туда где находится веди
      open show go goto take please me my the to a an page screen
      find navigate view display access abrir abre ir mostrar pagina página
    ].freeze

    class << self
      # Historical simple API used by earlier RC055.1f tests.
      def resolve(query)
        result = search(query)
        result.target&.key if result.status == :match
      end

      def search(query, workspace: nil, admin: false)
        cleaned = normalize(query)
        return Result.new(status: :not_found, candidates: []) if cleaned.empty? ||
          cleaned.length > 120 || query.to_s.match?(%r{https?://|www\.|[/\\]|[<>]}i)

        phrase = cleaned.split.reject { |word| STOP_WORDS.include?(word) }.join(" ")
        phrase = cleaned if phrase.empty?
        return Result.new(status: :not_found, candidates: []) if phrase.length < 2

        candidates = (pages(admin: admin) + service_pages(workspace)).filter_map do |page|
          score = best_score(phrase, page.aliases)
          [page, score] if score
        end
        candidates.sort_by! { |page, score| [-score, page.key] }
        return Result.new(status: :not_found, candidates: []) if candidates.empty?

        best = candidates.first[1]
        # Don't silently pick the wrong service or page for an ambiguous fragment.
        near = candidates.select { |_, score| score >= best - 12 }
        if near.length == 1
          Result.new(status: :match, target: near.first[0], candidates: [near.first[0]])
        else
          Result.new(status: :ambiguous, candidates: near.first(8).map(&:first))
        end
      end

      private

      def pages(admin:)
        items = DESTINATIONS.dup
        items.merge!(ADMIN_DESTINATIONS) if admin
        routes = Rails.application.routes.url_helpers
        items.map do |key, opts|
          args = if %w[today hour].include?(key)
            { date: Time.zone.today.iso8601 }
          else
            {}
          end
          Page.new(key: key, path: routes.public_send(opts.fetch(:path), **args),
                   label: I18n.t("owner_ai_assistant.destinations.#{key}", default: key.humanize),
                   aliases: opts.fetch(:aliases))
        end
      end

      def service_pages(workspace)
        return [] unless workspace

        routes = Rails.application.routes.url_helpers
        workspace.service_offerings.includes(:approved_version, :published_version, :versions)
          .order(:id).limit(200).filter_map do |offering|
          version = offering.draft_version || offering.approved_version || offering.published_version
          next unless version

          title = version.title.to_s
          Page.new(
            key: "service:#{offering.id}",
            label: title,
            path: routes.owner_service_path(offering),
            aliases: [title, "#{offering.key}", "услуга #{offering.id}", "service #{offering.id}"]
          )
        end
      end

      def normalize(value)
        text = value.is_a?(String) ? value : ""
        text.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.tr("ё", "е")
          .gsub(/[^\p{L}\p{N}]+/u, " ").strip.gsub(/\s+/, " ")
      end

      def best_score(phrase, aliases)
        return nil if phrase.empty?

        query_words = phrase.split(" ")
        aliases.filter_map do |wording|
          candidate = normalize(wording)
          words = candidate.split(" ")
          next if candidate.empty?

          if candidate == phrase
            160
          elsif phrase.length == 2 && words.include?(phrase)
            92
          elsif phrase.length == 2 && words.length == 1 && candidate.start_with?(phrase)
            90
          elsif phrase.length == 2 && words.any? { |word| word.start_with?(phrase) }
            74
          elsif candidate.start_with?(phrase) && phrase.length >= 3 &&
              (words.length == 1 || query_words.length >= 2)
            135
          elsif words.length == 1 && phrase.length >= 3 && candidate.include?(phrase)
            110
          elsif words.any? { |word| phrase.length >= 3 && word.start_with?(phrase) }
            98
          elsif phrase.length >= 4 && candidate.include?(phrase)
            91
          elsif query_words.length > 1 &&
                query_words.all? { |part| part.length >= 2 && words.any? { |word| word.start_with?(part) } }
            115
          elsif query_words.length == 1 && phrase.length >= 4 &&
                words.any? { |word| word.length >= 4 && distance(word, phrase) <= (phrase.length >= 7 ? 2 : 1) }
            73
          end
        end.max
      end

      # Levenshtein is only considered for short indexed labels; the input
      # length is bounded and this can NEVER construct a URL or action name.
      def distance(first, second)
        previous = (0..second.length).to_a
        first.each_char.with_index do |left, i|
          current = [i + 1]
          second.each_char.with_index do |right, j|
            current << [previous[j + 1] + 1, current[j] + 1,
                        previous[j] + (left == right ? 0 : 1)].min
          end
          previous = current
        end
        previous.last
      end
    end
  end
end
