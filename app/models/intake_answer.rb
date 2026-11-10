class IntakeAnswer < ApplicationRecord
  belongs_to :project_intake
  has_many :intake_answer_revisions, dependent: :restrict_with_exception

  validates :question_key, presence: true, length: { maximum: 64 },
                           uniqueness: { scope: :project_intake_id }
  validates :other_text, length: { maximum: 300 }
  validates :comment, length: { maximum: 500 }
  validates :revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :valid_quiz_choice

  def snapshot
    {
      "question_key" => question_key,
      "selected_options" => selected_options,
      "other_text" => other_text.to_s,
      "unsure" => unsure,
      "comment" => comment.to_s
    }
  end

  private

  def valid_quiz_choice
    question = Intake::QuizCatalog.question(project_intake&.project_type, question_key) ||
               Intake::AdaptiveQuestionCatalog.definition(project_intake&.project_type, question_key)
    unless question
      errors.add(:question_key, "is not part of this demo questionnaire")
      return
    end

    unless selected_options.is_a?(Array) && selected_options.length <= 10 &&
           selected_options.all? { |v| v.is_a?(String) && question[:options].key?(v) } &&
           selected_options.uniq.length == selected_options.length
      errors.add(:selected_options, "contain invalid or duplicate options")
      return
    end

    if question[:mode] == :single && selected_options.length > 1
      errors.add(:selected_options, "allow only one choice")
    end
    if unsure && (selected_options.any? || other_text.present?)
      errors.add(:unsure, "cannot be combined with other choices")
    elsif !unsure && selected_options.empty? && other_text.blank?
      errors.add(:base, "Choose an option, add your own answer, or select Not sure")
    end
  end
end
