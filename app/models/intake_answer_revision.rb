class IntakeAnswerRevision < ApplicationRecord
  belongs_to :intake_answer

  validates :revision, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :intake_answer_id }
  validates :snapshot, presence: true
end
