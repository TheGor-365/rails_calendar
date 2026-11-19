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
end
