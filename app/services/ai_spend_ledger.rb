# Production-grade allocation for the paid xAI path, with a small explicit pilot envelope.
# A PostgreSQL transaction-level advisory lock serializes budget reservations across workers.
# Reserved + uncertain attempts count at their full allowance. All totals are integer USD ticks:
#   1 USD = 10_000_000_000 ticks.
# Provider invoices can still exceed an allowance, e.g. a completed response reports larger usage;
# the excess is recorded and all future calls are denied until the ledger is reconciled.
class AiSpendLedger
  class LimitReached < StandardError; end
  class ReplayBlocked < StandardError; end
  class Unavailable < StandardError; end

  USD_TICKS = 10_000_000_000
  TOTAL_CAP_TICKS = 2 * USD_TICKS
  DAILY_CAP_TICKS = USD_TICKS / 2
  PROJECT_CAP_TICKS = USD_TICKS / 2
  PER_CALL_RESERVE_TICKS = USD_TICKS / 10
  ADVISORY_KEY = 20_261_113_051

  class << self
    def reserve!(project_intake:, operation:, model:, request_digest:)
      raise Unavailable, "PostgreSQL required" unless AiSpendEntry.connection.adapter_name == "PostgreSQL"
      raise Unavailable, "Invalid request fingerprint" unless request_digest.match?(/\A[0-9a-f]{64}\z/)

      AiSpendEntry.transaction do
        AiSpendEntry.connection.select_value("SELECT pg_advisory_xact_lock(#{ADVISORY_KEY})")
        existing = AiSpendEntry.find_by(request_digest: request_digest)
        if existing
          raise ReplayBlocked, "Previous request has uncertain billing or is in progress" unless existing.status == "settled"
          return [existing, false]
        end

        now = Time.current
        day_start = now.utc.beginning_of_day
        total = effective_sum(AiSpendEntry.all)
        today = effective_sum(AiSpendEntry.where("created_at >= ?", day_start))
        project = effective_sum(AiSpendEntry.where(project_intake_id: project_intake.id))
        reserve = PER_CALL_RESERVE_TICKS

        if total + reserve > TOTAL_CAP_TICKS ||
           today + reserve > DAILY_CAP_TICKS ||
           project + reserve > PROJECT_CAP_TICKS
          raise LimitReached, "Pilot USD budget exhausted"
        end

        entry = AiSpendEntry.create!(
          project_intake: project_intake, operation: operation, model: model,
          request_digest: request_digest, status: "reserved", reserved_ticks: reserve
        )
        [entry, true]
      end
    end

    def settle!(entry:, response:, result:)
      usage = response.fetch("usage")
      ticks = usage.fetch("cost_in_usd_ticks")
      unless ticks.is_a?(Integer) && ticks >= 0 && ticks <= USD_TICKS * 100
        raise Unavailable, "Invalid provider usage"
      end
      id = response["id"]
      id = nil unless id.is_a?(String) && id.bytesize <= 128
      raise Unavailable, "Invalid response data" unless result.is_a?(Hash)

      entry.with_lock do
        raise ReplayBlocked unless entry.status == "reserved"
        entry.update!(
          status: "settled", charged_ticks: ticks, provider_response_id: id,
          usage: usage.slice("input_tokens", "output_tokens", "total_tokens", "cost_in_usd_ticks"),
          result: result, resolved_at: Time.current
        )
      end
      result
    end

    def uncertain!(entry:)
      entry.with_lock do
        entry.update!(status: "uncertain", resolved_at: Time.current) if entry.status == "reserved"
      end
    end

    def cancelled!(entry:)
      entry.with_lock do
        entry.update!(status: "cancelled", reserved_ticks: 0, resolved_at: Time.current) if entry.status == "reserved"
      end
    end

    def spend_summary
      {
        billed_ticks: AiSpendEntry.where(status: "settled").sum(:charged_ticks),
        held_ticks: AiSpendEntry.where(status: %w[reserved uncertain]).sum(:reserved_ticks),
        cap_ticks: TOTAL_CAP_TICKS
      }
    end

    private

    def effective_sum(scope)
      scope.sum(Arel.sql("CASE WHEN status = 'settled' THEN COALESCE(charged_ticks, reserved_ticks) ELSE reserved_ticks END")).to_i
    end
  end
end
