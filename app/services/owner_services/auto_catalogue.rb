module OwnerServices
  # Offline conversion of the *approved* owner interview into private draft
  # offerings. No AI call, automatic publication, price or guaranteed result.
  class AutoCatalogue
    Result = Struct.new(:created, :revised, :unchanged, :deferred, keyword_init: true)

    # [title, legacy grouping, preferred source domains, summary, included,
    #  excluded, inputs]. Keep text bounded; owner can edit each draft.
    RULES = {
      "rails_bugfix" => [
        "Исправление ошибок веб-приложений", "rails_bugfix", %w[rails ruby],
        "Исправлю конкретную воспроизводимую ошибку Rails-приложения после изучения симптомов, кода и требований.",
        "Диагностика одного сбоя, ограниченное исправление, регрессионная проверка и описание результата.",
        "Не входят полный аудит продукта, срочное дежурство и неограниченная поддержка.",
        "Версия Rails, шаги воспроизведения, обезличенный лог, ожидаемый результат."
      ],
      "rails_crud" => [
        "Личные кабинеты, формы и управление данными", "website", %w[rails],
        "Добавлю формы, личные кабинеты или административные экраны в существующее Rails-приложение.",
        "Уточнение сценариев, реализация согласованных операций и проверка переходов.",
        "Не входят крупная перестройка системы и дополнительные функции вне согласованного объёма.",
        "Сущности, поля, роли, макет, критерии приёмки."
      ],
      "rails_api" => [
        "Интеграция сайтов и сервисов", "api_integration", %w[api rails],
        "Свяжу ваше приложение с другим сервисом через REST API после оценки необходимого обмена данными.",
        "Разбор API-контракта, согласованные endpoints, тестовые запросы и проверка ошибок.",
        "Не входят бесконечная поддержка API и обход правил сторонних платформ.",
        "Документация API, обезличенные ответы, список операций."
      ],
      "rails_tests" => [
        "Проверка и повышение надёжности приложений", "rails_bugfix", %w[testing rails],
        "Добавлю и исправлю автоматические тесты для согласованных Rails-сценариев и воспроизводимых регрессий.",
        "Разбор тестового стека, регрессионные примеры, запуск и отчёт о результатах.",
        "Не входят обещание 100% покрытия и аудит безопасности без отдельной оценки.",
        "Стек тестирования, текущая ошибка, способ локального запуска."
      ],
      "websites" => [
        "Сайты и адаптивные лендинги", "website", %w[tilda html_css bootstrap rails],
        "Сделаю небольшой сайт или доработаю лендинг с адаптивными секциями и понятным пользовательским сценарием.",
        "Структура страниц, оговорённые блоки, формы и проверка мобильного отображения.",
        "Не входят гарантия продаж и неограниченное производство текстов и дизайна.",
        "Цель сайта, референсы, контент, доступный инструмент публикации."
      ],
      "automation" => [
        "Автоматизация рабочих процессов", "api_integration", %w[automation ruby rails api],
        "Подготовлю ограниченный сценарий автоматизации обработки данных или взаимодействия сервисов.",
        "Анализ входов и выходов, один согласованный сценарий, проверка обработки ошибок.",
        "Не входят обещания полностью автономных решений и работа с секретами без безопасного процесса.",
        "Описание ручного процесса, обезличенные примеры, ожидаемый результат."
      ],
      "ai_integrations" => [
        "ИИ-помощники и интеллектуальные функции", "api_integration", %w[ai_agents automation api rails],
        "Оценю и реализую ограниченную AI-функцию с контролем качества, приватности и возможностью ручного решения.",
        "Уточнение сценария, бюджетных ограничений, прототип и тесты ожидаемых ответов.",
        "Не входят гарантии безошибочности ИИ, платные вызовы без согласования и автономные решения с высоким риском.",
        "Сценарий пользователя, ограничения приватности, бюджет и критерии качества."
      ],
      "data_tasks" => [
        "CSV, таблицы и обработка данных", "api_integration", %w[postgresql ruby api],
        "Обработаю небольшой набор CSV или табличных данных по согласованным проверяемым правилам.",
        "Проверка структуры, очистка или преобразование согласованных полей и контроль результата.",
        "Не входят финансовый аудит и гарантии качества неизвестных исходных данных.",
        "Обезличенный образец, формат результата и правила преобразования."
      ],
      "adjacent_web" => [
        "Веб-интерфейсы и прототипы", "website", %w[vue react javascript html_css],
        "Оценю и реализую небольшой веб-интерфейс или прототип с учётом выбранного стека и границ компетенций.",
        "Один согласованный интерфейсный сценарий, адаптивность и базовая проверка.",
        "Не входят обещание экспертизы в незнакомом стеке и разработка крупного продукта без оценки.",
        "Макеты, стек, целевой экран, критерии приёмки."
      ]
    }.freeze

    def initialize(workspace:)
      @workspace = workspace
    end

    def sync!
      catalogue = Catalogue.new(workspace: @workspace)
      profile = catalogue.profile
      snapshot = catalogue.snapshot
      raise Catalogue::PolicyError, "Approved professional context required" unless
        snapshot && profile.onboarding_state == "approved" &&
        profile.professional_capability_corrections.none?

      interests = Array(snapshot.payload["desired_services"]).map(&:to_s).uniq
      capabilities = catalogue.eligible_capabilities.to_a
      result = Result.new(created: 0, revised: 0, unchanged: 0, deferred: 0)

      @workspace.with_lock do
        RULES.each do |interest, rule|
          next unless interests.include?(interest)
          capability = rule[2].filter_map { |domain| capabilities.find { |cap| cap.domain == domain } }.first
          next unless capability

          fields = proposed_copy(rule, capability)
          key = "auto-#{interest.tr("_", "-")}"
          offering = @workspace.service_offerings.find_by(key: key)

          if offering.nil?
            catalogue.create_draft!(fields.merge(professional_capability_id: capability.id),
                                    stable_key: key)
            result.created += 1
          elsif offering.versions.exists?(professional_context_snapshot_id: snapshot.id)
            result.unchanged += 1
          elsif offering.draft_version || offering.approved_version.nil?
            # Keep manual edits, including edits to drafts from an older snapshot.
            result.deferred += 1
          else
            offering.with_lock do
              offering.versions.create!(
                fields.merge(
                  version: offering.versions.maximum(:version).to_i + 1,
                  professional_context_snapshot: snapshot,
                  professional_capability: capability,
                  source_capability_domain: capability.domain,
                  delivery_mode: Catalogue.delivery_mode_for(capability)
                )
              )
            end
            result.revised += 1
          end
        end
      end
      result
    end

    private

    def proposed_copy(rule, capability)
      mode = Catalogue.delivery_mode_for(capability)
      qualification = mode == "direct" ? "" : " Требуется предварительная проверка опыта и трудоёмкости."
      {
        title: rule[0], project_category: rule[1],
        summary: "#{rule[3]}#{qualification}",
        included_scope: rule[4], excluded_scope: rule[5],
        requirements_prompt: rule[6]
      }
    end
  end
end
