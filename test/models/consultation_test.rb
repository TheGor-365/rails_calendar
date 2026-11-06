require "test_helper"

class ConsultationTest < ActiveSupport::TestCase
  test "valid fixture has increasing start and end times" do
    assert consultations(:one).valid?
  end

  test "title and both times are required" do
    consultation = Consultation.new

    assert_not consultation.valid?
    assert_includes consultation.errors.attribute_names, :title
    assert_includes consultation.errors.attribute_names, :start_time
    assert_includes consultation.errors.attribute_names, :end_time
  end

  test "end time must be after start time" do
    consultation = consultations(:one)
    consultation.end_time = consultation.start_time

    assert_not consultation.valid?
    assert_includes consultation.errors[:end_time], "must be after start time"

    consultation.end_time = consultation.start_time - 1.minute

    assert_not consultation.valid?
    assert_includes consultation.errors[:end_time], "must be after start time"
  end

  test "rejects nonsensical historical and far future years" do
    consultation = consultations(:one)
    consultation.start_time = Time.zone.local(1212, 12, 12, 12, 12)
    consultation.end_time = Time.zone.local(2101, 12, 12, 13, 12)

    assert_not consultation.valid?
    assert_includes consultation.errors[:start_time], "must be between years 2000 and 2100"
    assert_includes consultation.errors[:end_time], "must be between years 2000 and 2100"
  end

  test "accepts supported schedule years" do
    consultation = consultations(:one)
    consultation.start_time = Time.zone.local(2099, 12, 12, 12, 12)
    consultation.end_time = consultation.start_time + 1.hour

    assert consultation.valid?
  end

  test "bounds public text field lengths" do
    consultation = consultations(:one)
    consultation.title = "X" * 121
    consultation.description = "Y" * 5_001

    assert_not consultation.valid?
    assert_includes consultation.errors.attribute_names, :title
    assert_includes consultation.errors.attribute_names, :description
  end
end
