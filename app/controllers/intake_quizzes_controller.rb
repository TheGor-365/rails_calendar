class IntakeQuizzesController < ApplicationController
  before_action :require_quiz_owner!
  before_action :set_intake
  before_action :set_questions

  def show
    @saved_answers = saved_answers
    step = params[:step].presence

    # Enter the first unfinished step, or review once both cards are saved.
    if step.blank?
      unfinished = @questions.find { |question| !@saved_answers.key?(question.fetch(:key)) }
      return redirect_to review_project_intake_quiz_path(@intake) unless unfinished

      step = unfinished.fetch(:key)
    end

    @position = @questions.index { |question| question.fetch(:key) == step }
    return head :not_found unless @position

    @question = @questions.fetch(@position)
    @answer = @saved_answers[step] || @intake.intake_answers.build(question_key: step)
  end

  def update
    @position = @questions.index { |question| question.fetch(:key) == params[:question_key] }
    return head :not_found unless @position

    @question = @questions.fetch(@position)
    attributes = quiz_params
    selections = Array(attributes[:selected_options]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    navigation = %w[continue review back intake].include?(attributes[:navigation]) ? attributes[:navigation] : "continue"
    stored = false

    # Serialize updates to this intake; the draft and every changed snapshot commit together.
    @intake.with_lock do
      @answer = @intake.intake_answers.find_or_initialize_by(question_key: @question.fetch(:key))
      @answer.assign_attributes(
        selected_options: selections,
        other_text: attributes[:other_text].to_s.strip,
        unsure: attributes[:unsure] == "1",
        comment: attributes[:comment].to_s.strip
      )
      if @answer.valid?
        changed = @answer.new_record? || @answer.changed?
        if changed
          @answer.revision += 1
          @answer.save!
          @answer.intake_answer_revisions.create!(revision: @answer.revision, snapshot: @answer.snapshot)
        end
        stored = true
      end
    end

    unless stored
      @saved_answers = saved_answers
      return render :show, status: :unprocessable_entity
    end

    next_question = @questions[@position + 1]
    destination = case navigation
                  when "review"
                    review_project_intake_quiz_path(@intake)
                  when "back"
                    previous_question = @questions[@position - 1] if @position.positive?
                    project_intake_quiz_path(@intake, step: (previous_question || @question).fetch(:key))
                  when "intake"
                    project_intake_path(@intake)
                  else
                    next_question ? project_intake_quiz_path(@intake, step: next_question.fetch(:key)) : review_project_intake_quiz_path(@intake)
                  end
    redirect_to destination, notice: "Quiz draft saved"
  end

  def review
    @saved_answers = saved_answers
    @unfinished_question = @questions.find { |question| !@saved_answers.key?(question.fetch(:key)) }
  end

  private

  def require_quiz_owner!
    return if owner_signed_in?

    redirect_to sign_in_path, alert: "Owner sign-in required for quiz"
  end

  def set_intake
    @intake = ProjectIntake.find(params[:project_intake_id])
    if @intake.workspace_id.present? && !@intake.workspace.owner_access?(current_user)
      head :not_found
    end
  end

  def set_questions
    @questions = Intake::QuizCatalog.for(@intake.project_type)
    head :not_found if @questions.empty?
  end

  def saved_answers
    @intake.intake_answers.index_by(&:question_key)
  end

  def quiz_params
    params.require(:quiz).permit(:other_text, :unsure, :comment, :navigation, selected_options: [])
  end
end
