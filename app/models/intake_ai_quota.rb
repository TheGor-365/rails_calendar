# Persistent daily call cap shared by all Rails workers, independent of session.
# Reserving counts attempted calls, including failures, rather than risking a retry storm.
class IntakeAiQuota < ApplicationRecord
  self.table_name = "intake_ai_quotas"
  MAX_CALLS_PER_UTC_DAY = 12

  def self.reserve_call!
    quota = create_or_find_by!(usage_day: Date.current)
    quota.with_lock do
      return false if quota.call_count >= MAX_CALLS_PER_UTC_DAY

      quota.update!(call_count: quota.call_count + 1)
    end
    true
  end
end
