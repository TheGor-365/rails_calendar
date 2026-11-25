module OwnerServices
  # A read-only presentation of an explicitly published version.
  # Private capability rows can constrain claims, but cannot introduce
  # information absent from the already published commercial copy.
  class PublicPresentation
    TECHNOLOGIES = {
      "rails" => /Ruby on Rails|\bRails\b/i,
      "ruby" => /\bRuby\b(?! on Rails)/i,
      "postgresql" => /\bPostgreSQL\b/i,
      "html_css" => /\bHTML\b|\bCSS\b/i,
      "bootstrap" => /\bBootstrap\b/i,
      "javascript" => /\bJavaScript\b/i,
      "hotwire" => /\bHotwire\b|\bTurbo\b|\bStimulus\b/i,
      "testing" => /\bRSpec\b|\bMinitest\b/i,
      "api" => /\bREST API\b/i,
      "tilda" => /\bTilda\b/i,
      "react" => /\bReact\b/i,
      "vue" => /\bVue\b/i,
      "python" => /\bPython\b/i
    }.freeze

    def initialize(offering)
      @version = offering.published_version
    end

    def technology_domains
      return [] unless @version&.approved?
      snapshot = @version.professional_context_snapshot
      copy = [@version.title, @version.summary, @version.included_scope].join(" ")
      snapshot.professional_profile.professional_capabilities
        .where(snapshot_version: snapshot.version, domain: TECHNOLOGIES.keys)
        .where.not(delivery_mode: "excluded")
        .where.not(willingness: "not_interested")
        .order(:domain).filter_map do |capability|
          domain = capability.domain
          domain if TECHNOLOGIES.fetch(domain).match?(copy)
        end
    end
  end
end
