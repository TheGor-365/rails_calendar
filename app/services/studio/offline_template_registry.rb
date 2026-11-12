module Studio
  # Static offline templates. No model instructions, untrusted source bodies,
  # retrieval, URLs, provider SDK or remote prompt interpolation.
  class OfflineTemplateRegistry
    VERSION = "rc037-static-templates-v1"
    TEXT = {
      "clarify" => "Synthetic clarification checklist: confirm stakeholders, intended outcomes, scope exclusions and acceptance evidence. Unverified until a human reviews.",
      "source_outline" => "Synthetic source inventory outline: cross-check each source format, checksum, attribution, review status and missing evidence. No source text was retrieved.",
      "document_proposal" => "Synthetic document proposal: draft brief, requirements, architecture, QA and release plan only after source verification and explicit approval."
    }.freeze

    def self.render!(purpose:)
      TEXT.fetch(purpose) { raise ArgumentError, "Unregistered offline template" }
    end
  end
end
