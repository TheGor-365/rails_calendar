class OwnerInterviewAnswerRevision < ApplicationRecord
  belongs_to :owner_interview_answer

  validates :revision, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :owner_interview_answer_id }
  before_update { raise ActiveRecord::ReadOnlyError, "Interview history is immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyError, "Interview history is immutable" }
end
