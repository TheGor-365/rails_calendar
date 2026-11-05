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
end
