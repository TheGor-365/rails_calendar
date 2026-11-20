# Shared keys for the client-facing project discovery and the owner's technical review.
# Never embed untrusted section names in prompt instructions or SQL.
module IntakeScopeSections
  ITEMS = {
    "business_goal" => "bi-bullseye",
    "audiences" => "bi-people",
    "journeys" => "bi-diagram-3",
    "features" => "bi-ui-checks-grid",
    "data" => "bi-database",
    "quality" => "bi-shield-check",
    "content_design" => "bi-palette",
    "acceptance" => "bi-clipboard-check",
    "exclusions" => "bi-slash-circle",
    "risks" => "bi-exclamation-diamond",
    "breakdown" => "bi-list-task",
    "estimate" => "bi-calendar3"
  }.freeze
  KEYS = ITEMS.keys.freeze
  STATUSES = %w[suggested confirmed unknown excluded].freeze
  RESPONSIBILITIES = %w[client owner open].freeze

  def self.normalize(raw)
    return nil unless raw.is_a?(Hash)
    return nil unless (raw.keys - KEYS).empty?

    normalized = {}
    raw.each do |key, value|
      return nil unless value.is_a?(Hash)
      return nil unless (value.keys - %w[text status responsibility]).empty?
      text = value.fetch("text", "")
      status = value.fetch("status", "unknown")
      return nil unless text.is_a?(String) && text.length <= 1600
      responsibility = value.fetch("responsibility", "open")
      return nil unless STATUSES.include?(status) && RESPONSIBILITIES.include?(responsibility)
      normalized[key] = { "text" => text.strip, "status" => status, "responsibility" => responsibility }
    end
    normalized
  end
end
