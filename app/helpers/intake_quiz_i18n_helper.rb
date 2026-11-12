module IntakeQuizI18nHelper
  # Only presentation copy changes; canonical question/option keys and snapshots stay intact.
  def rc_quiz_question_title(question)
    I18n.t("quiz.question_#{question.fetch(:key)}", default: question.fetch(:title))
  end

  def rc_quiz_option_label(project_type, question, option_key)
    original = question.fetch(:options).fetch(option_key, option_key)
    I18n.t("quiz.options.#{project_type}.#{question.fetch(:key)}.#{option_key}", default: original)
  end
end
