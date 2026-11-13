class OwnerInterviewAnswer < ApplicationRecord
  belongs_to :professional_profile
  has_many :owner_interview_answer_revisions, dependent: :restrict_with_exception

  validates :section_key, inclusion: { in: OwnerIntelligence::Catalog::KEYS },
                          uniqueness: { scope: :professional_profile_id }
  validates :revision, numericality: { only_integer: true, greater_than: 0 }
  validates :notes, length: { maximum: 800 }, allow_nil: true
  validate :allowed_selected_options

  def snapshot
    { "section_key" => section_key, "selected_options" => selected_options,
      "notes" => notes.to_s, "unsure" => unsure, "revision" => revision }
  end

  private

  def allowed_selected_options
    allowed = OwnerIntelligence::Catalog.options_for(section_key).keys
    unless selected_options.is_a?(Array) && selected_options.length <= 15 &&
           selected_options.all? { |item| item.is_a?(String) && allowed.include?(item) } &&
           selected_options.uniq == selected_options
      errors.add(:selected_options, "contain an invalid option")
    end
  end
end
