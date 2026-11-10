require "cgi"

module Studio
  # A deterministic, offline MD handoff *preview*, never an approved SRS or
  # customer-facing proposal. No model calls, storage, or implied facts.
  class DraftBriefRenderer
    VERSION = "draft-brief.v1".freeze

    def call(intake:, report:, actor:)
      unless intake.is_a?(ProjectIntake) && intake.persisted? &&
             intake.workspace && intake.client &&
             intake.workspace.owner_access?(actor) &&
             intake.client.workspace_id == intake.workspace_id
        raise SecurityError, "Scoped owner access required"
      end
      unless report.is_a?(Hash) &&
             report["classification"] == "UNTRUSTED_OWNER_PREVIEW_NOT_PERSISTED" &&
             report["stored"] == false && report["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
        raise ArgumentError, "An inspected source is required"
      end

      lines = [
        "# Draft discovery brief — NOT APPROVED",
        "",
        "> Internal owner-only preview generated deterministically. Source",
        "> content is untrusted. No customer, scope, price or deadline acceptance.",
        "",
        "- Renderer version: #{VERSION}",
        "- Project intake ID: #{intake.id}",
        "- Project title (owner entered): #{safe(intake.title)}",
        "- Project type: #{safe(intake.project_type)}",
        "- Source format: #{safe(report.fetch("format"))}",
        "- Source SHA256: #{report.fetch("sha256")}",
        "- Source line count: #{report.fetch("line_count")}",
        "",
        "## Source outline — unverified"
      ]
      headings = Array(report["outline"])
      lines << "No headings extracted." if headings.empty?
      headings.each do |row|
        lines << "- Line #{row.fetch("line")}: #{safe(row.fetch("title"))}"
      end

      lines += ["", "## Checklist candidates — unverified"]
      tasks = Array(report["checklist"])
      lines << "No Markdown checklist found." if tasks.empty?
      tasks.each do |row|
        lines << "- [#{row.fetch("done") ? "x" : " "}] #{safe(row.fetch("text"))} (source line #{row.fetch("line")})"
      end

      lines += [
        "", "## Clarification and approval gates",
        "- Verify source ownership and permission to process.",
        "- Confirm goals, actors, scope and acceptance criteria with the client.",
        "- Mark unverified suggestions and unknowns before writing a specification.",
        "- No implementation schedule or financial commitment is approved here.",
        "", "## Provenance",
        "Source SHA256 identifies the provided bytes; this export is not proof that source content is accurate.",
        "No original file or private content was stored by the Project Studio preview."
      ]
      lines.join("\n") + "\n"
    end

    private

    def safe(value)
      CGI.escapeHTML(value.to_s.gsub(/[\r\n\t]+/, " ").slice(0, 180))
         .gsub("|", "\\|")
    end
  end
end
