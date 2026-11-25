module IntakeBrief
  # Restricted, deterministic context for a future opt-in AI draft.
  # Constructing this object NEVER calls an AI provider or sends any data.
  # A caller must still enforce owner/client ACL, consent and cost controls.
  class PromptContext
    AUDIENCES = %w[client owner].freeze

    CLIENT_INSTRUCTIONS = [
      "Speak as a concise professional; never condescend.",
      "Lead with the outcome, next step and any open question.",
      "Explain technical terms in plain language in one sentence each.",
      "Preserve the exact technology names as secondary labels.",
      "Ask about behavior and acceptance criteria, not framework knowledge.",
      "Explicitly mark unknowns and whose decision is pending.",
      "Do not invent prices, deadlines, capabilities, agreements or delivered work.",
      "Do not request credentials, access tokens, private files or personal identifiers."
    ].freeze

    OWNER_INSTRUCTIONS = [
      "Lead with specific scope, dependency, acceptance criteria and missing facts.",
      "Use precise implementation terminology but mark uncertain assumptions.",
      "Separate suggested technologies from the owner's verified capabilities.",
      "Do not invent estimates, delivery guarantees, approval or client consent.",
      "Never include private client or owner context outside the authorised brief."
    ].freeze

    def initialize(revision:, audience:, locale: I18n.locale)
      raise ArgumentError, "unsupported audience" unless AUDIENCES.include?(audience.to_s)
      raise ArgumentError, "unsaved revision" unless revision&.persisted?
      @revision = revision
      @audience = audience.to_s
      @locale = I18n.available_locales.include?(locale.to_sym) ? locale.to_sym : :en
    end

    def as_json(*)
      {
        "audience" => @audience,
        "locale" => @locale.to_s,
        "revision" => @revision.version,
        "instructions" => @audience == "client" ? CLIENT_INSTRUCTIONS : OWNER_INSTRUCTIONS,
        "sections" => InvitationBriefTaxonomy.sections.map do |group, available|
          chosen = Array(@revision.selections[group]) & available
          {
            "section" => group,
            "label" => I18n.t("e2_client_brief.groups.#{group}", locale: @locale),
            "decision" => @revision.decisions.fetch(group, "skip"),
            "choices" => chosen.map do |option|
              result = {
                "key" => option,
                "technology" => I18n.t("e2_builder.options.#{option}", locale: @locale)
              }
              if @audience == "client"
                result["plain_explanation"] = I18n.t("e2_client_brief.explain.#{option}", locale: @locale)
              end
              result
            end
          }
        end,
        "clarification" => @revision.notes.to_s.truncate(350)
      }
    end
  end
end
