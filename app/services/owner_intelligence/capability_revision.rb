require "digest"
require "json"

module OwnerIntelligence
  # No AI suggestions, user input or missing evidence can silently elevate
  # a capability to verified. All changes are private, explicitly confirmed,
  # versioned and only take effect after an owner approval transaction.
  class CapabilityRevision
    class Stale < StandardError; end
    class Invalid < StandardError; end

    def self.merge!(payload, corrections:)
      data = payload.deep_dup
      present = data.fetch("capabilities").index_by { |row| row.fetch("domain") }
      corrections.each do |correction|
        row = present[correction.domain]
        raise Invalid, "Capability no longer exists in the interview" unless row

        row.merge!(
          "delivery_mode" => correction.delivery_mode,
          "experience_claim" => correction.experience_claim,
          "willingness" => correction.willingness,
          "conditions" => correction.conditions.to_s,
          "review_required" => true
        )
        # Never raise confidence without independently reviewed evidence.
        row["evidence_status"] = "unverified" if correction.experience_claim != "practiced"
        row["privacy_scope"] = "private"
      end
      data
    end

    def self.approve!(profile:, base_version:, headline:, private_summary:, public_summary:)
      profile.with_lock do
        source = profile.approved_snapshot
        raise Invalid, "No approved baseline" unless source
        raise Stale, "Approved profile has changed" unless source.version == base_version.to_i

        current_answers = Catalog::KEYS.to_h do |key|
          answer = profile.owner_interview_answers.find_by(section_key: key)
          [key, answer&.snapshot]
        end
        unless current_answers == source.payload.fetch("interview_answers")
          raise Stale, "Interview changes must be reviewed first"
        end

        edits = profile.professional_capability_corrections.order(:domain).to_a
        raise Invalid, "Nothing to approve" if edits.empty?
        raise Stale, "Corrections are based on another version" unless edits.all? { |e| e.base_snapshot_version == source.version }

        payload = merge!(source.payload, corrections: edits)
        payload["headline"] = headline
        payload["private_summary"] = private_summary
        payload["public_summary_draft"] = public_summary
        payload["source"] = "owner_confirmed"
        payload["revision_reason"] = "capability_reclassification"
        payload["origin_snapshot_version"] = source.version
        payload["capability_changes"] = edits.map(&:snapshot_values)

        version = source.version + 1
        snapshot = profile.professional_context_snapshots.create!(
          version: version, payload: payload,
          digest: Digest::SHA256.hexdigest(JSON.generate(payload)), approved_at: Time.current
        )
        payload.fetch("capabilities").each do |item|
          profile.professional_capabilities.create!(
            snapshot_version: version, domain: item.fetch("domain"),
            delivery_mode: item.fetch("delivery_mode"),
            experience_claim: item.fetch("experience_claim"),
            evidence_status: item.fetch("evidence_status"),
            willingness: item.fetch("willingness"),
            privacy_scope: item.fetch("privacy_scope"),
            review_required: true,
            conditions: item.fetch("conditions")
          )
        end
        policy = profile.work_policies.find_by!(snapshot_version: source.version)
        profile.work_policies.create!(
          snapshot_version: version, hard_no_go: policy.hard_no_go,
          work_preferences: policy.work_preferences, notes: policy.notes
        )
        profile.update!(headline: headline, private_summary: private_summary,
                        public_summary: public_summary, onboarding_state: "approved")
        profile.professional_capability_corrections.delete_all
        snapshot
      end
    end
  end
end
