module OwnerAi
  # Free, deterministic navigation. No LLM decides URL targets or executes Rails methods.
  # Only owner-scoped locations are eligible; controller resolves them to route helpers.
  class Navigator
    PATTERNS = {
      "catalogue_ai" => /(?:каталог.*(?:ии|ai)|ии.*каталог|catalog(?:ue)?\s+ai|audit\s+services)/i,
      "services" => /(?:услуг|каталог|сервис|services|servicios|ծառայութ)/i,
      "cabinet" => /(?:кабинет|профил|cabinet|profile|panel\s+personal|աշխատասեն)/i,
      "capabilities" => /(?:навык|компетен|skills|capabilit|competenc)/i,
      "interview" => /(?:интервью|знакомств|interview|onboarding)/i,
      "spending" => /(?:расход|бюджет|spend|costs?|gastos)/i,
      "calendar" => /(?:календар|calendar|calendario)/i,
      "today" => /(?:сегодня|today|hoy)/i,
      "consultations" => /(?:консультац|consultations?|consultas)/i,
      "workspace" => /(?:рабоч.*област|рабоч.*простран|главн|workspace|dashboard|inicio)/i,
      "assistant" => /(?:помощник|ассистент|assistant|ayudante)/i
    }.freeze

    def self.resolve(query)
      command = query.to_s.strip
      return nil unless command.length.between?(4, 120)
      return nil unless command.match?(/\A(?:открой|перейди|покажи|покажи\s+мне|open|go\s+to|show|abrir|ir\s+a)\s+/i)
      PATTERNS.find { |_key, matcher| command.match?(matcher) }&.first
    end
  end
end
