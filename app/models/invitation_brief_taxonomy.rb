# E2.1: server-owned allowlist of task categories for the local invitation brief.
# These are selectable examples, NOT assertions about the owner's proven skills.
# Structured persistence/versioning is a separate migration-gated phase.
class InvitationBriefTaxonomy
  SECTIONS = {
    "tasks" => %w[bugfix forms api tests ui automation],
    "frontend" => %w[html bootstrap stimulus javascript vite vue],
    "backend" => %w[ruby rails postgresql redis],
    "deployment" => %w[railway vps docker github_actions dns_ssl]
  }.freeze

  ICONS = {
    "tasks" => "bi-ui-checks-grid",
    "frontend" => "bi-window-stack",
    "backend" => "bi-database",
    "deployment" => "bi-cloud-arrow-up"
  }.freeze

  DECISIONS = %w[skip client owner].freeze

  def self.sections
    SECTIONS
  end

  def self.valid?(selections)
    selections.is_a?(Hash) &&
      selections.keys.all? { |section| SECTIONS.key?(section.to_s) } &&
      selections.all? do |section, values|
        values.is_a?(Array) && values.size <= SECTIONS.fetch(section.to_s).size &&
          values.uniq == values && values.all? { |value| SECTIONS.fetch(section.to_s).include?(value) }
      end
  end
  def self.valid_decisions?(decisions)
    decisions.is_a?(Hash) &&
      decisions.keys.all? { |section| SECTIONS.key?(section.to_s) } &&
      decisions.values.all? { |value| DECISIONS.include?(value) }
  end

  def self.clean_selections(raw)
    return {} unless raw.respond_to?(:to_unsafe_h) || raw.is_a?(Hash)
    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
    SECTIONS.keys.index_with do |section|
      Array(hash[section]).map(&:to_s).reject(&:blank?)
    end.reject { |_section, values| values.empty? }
  end

  def self.clean_decisions(raw)
    return {} unless raw.respond_to?(:to_unsafe_h) || raw.is_a?(Hash)
    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
    SECTIONS.keys.index_with { |section| hash[section].to_s }
      .reject { |_section, decision| decision.blank? || decision == "skip" }
  end

end
