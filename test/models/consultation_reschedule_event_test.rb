require "test_helper"

class ConsultationRescheduleEventTest < ActiveSupport::TestCase
  test "history snapshots are append-only through the Active Record model" do
    consultation = consultations(:two)
    entry = ConsultationRescheduleEvent.create!(
      consultation_id: consultation.id,
      old_start_time: consultation.start_time,
      old_end_time: consultation.end_time,
      new_start_time: consultation.start_time + 15.minutes,
      new_end_time: consultation.end_time + 15.minutes,
      actor_label: "administrator",
      reason: "Approved schedule adjustment",
      created_at: Time.current
    )

    assert_predicate entry, :readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      entry.update!(reason: "Tampered")
    end
    assert_raises(ActiveRecord::ReadOnlyRecord) { entry.destroy! }
    assert_equal "Approved schedule adjustment", ConsultationRescheduleEvent.find(entry.id).reason
  end

  test "history requires a real time difference and bounded reason" do
    consultation = consultations(:two)
    unchanged = ConsultationRescheduleEvent.new(
      consultation_id: consultation.id,
      old_start_time: consultation.start_time,
      old_end_time: consultation.end_time,
      new_start_time: consultation.start_time,
      new_end_time: consultation.end_time,
      actor_label: "administrator",
      reason: "A description change only",
      created_at: Time.current
    )
    assert_not unchanged.valid?
    assert_includes unchanged.errors.full_messages.join(" "), "changed time"

    unchanged.new_end_time += 1.minute
    unchanged.reason = "x" * 501
    assert_not unchanged.valid?
    assert_includes unchanged.errors.attribute_names, :reason
  end
end
