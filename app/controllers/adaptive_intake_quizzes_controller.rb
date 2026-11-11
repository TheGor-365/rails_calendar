# RC-035B: a separate, owner-only adaptive preview. Public/client intake stays closed.
# The two-card RC-034 quiz controller and routes remain untouched.
class AdaptiveIntakeQuizzesController < ApplicationController
  before_action :require_owner!
  before_action :set_intake

  def show
    refresh_questions
    step = params[:step].presence

    if step.blank?
      pending = @questions.find { |question| !@saved_answers.key?(question.fetch(:key)) }
      return redirect_to review_adaptive_project_intake_quiz_path(@intake) unless pending

      step = pending.fetch(:key)
    end

    @position = @questions.index { |question| question.fetch(:key) == step }
    return head :not_found unless @position

    @question = @questions.fetch(@position)
    @answer = @saved_answers[step] ||
              @intake.intake_answers.build(question_key: step)
  end

  def update
    input = quiz_params
    navigation = %w[continue back review intake].include?(input[:navigation]) ? input[:navigation] : "continue"
    saved = false
    hidden = false

    # Serialize the visibility decision, optimistic revision check, answer write
    # and immutable snapshot. A stale browser tab must not overwrite newer data.
    @intake.with_lock do
      refresh_questions
      @position = @questions.index { |question| question.fetch(:key) == params[:question_key] }
      if @position.nil?
        hidden = true
      else
        @question = @questions.fetch(@position)
        @answer = @intake.intake_answers.find_or_initialize_by(question_key: @question.fetch(:key))
        submitted_revision = input[:revision].to_s
        if !submitted_revision.match?(/\A\d+\z/) || submitted_revision.to_i != @answer.revision
          @answer.errors.add(:base, "This answer changed in another tab. Reload before saving.")
        else
          selections = Array(input[:selected_options]).map(&:to_s).map(&:strip).reject(&:blank?)
          submitted_priorities = input[:feature_priorities]&.to_h || {}
          selected_priorities = if Intake::AdaptiveQuestionCatalog.prioritizable?(@question.fetch(:key))
                                  submitted_priorities.slice(*selections)
                                else
                                  {}
                                end
          @answer.assign_attributes(
            selected_options: selections,
            feature_priorities: selected_priorities,
            other_text: input[:other_text].to_s.strip,
            unsure: input[:unsure] == "1",
            comment: input[:comment].to_s.strip
          )
          if @answer.valid?
            # Changing a parent can make already-saved child answers inactive.
            # Never do so silently: require an explicit confirmation while
            # keeping all child records and immutable snapshots intact.
            newly_hidden = newly_hidden_saved_count
            if newly_hidden.positive? && input[:confirm_branch_change] != "1"
              @needs_branch_confirmation = true
              @answer.errors.add(:base, "This change will hide #{newly_hidden} previously saved answer(s). Confirm below before saving.")
            else
              if @answer.new_record? || @answer.changed?
                @answer.revision += 1
                @answer.save!
                @answer.intake_answer_revisions.create!(
                  revision: @answer.revision,
                  snapshot: @answer.snapshot.merge(
                    "catalog_version" => Intake::AdaptiveQuestionCatalog::VERSION,
                    "question_title" => @question.fetch(:title),
                    "selected_labels" => @answer.selected_options.to_h do |key|
                      [key, @question.fetch(:options).fetch(key)]
                    end
                  )
                )
              end
              saved = true
            end
          end
        end
      end
    end

    return head :not_found if hidden
    return render :show, status: :unprocessable_entity unless saved

    refresh_questions
    position = @questions.index { |question| question.fetch(:key) == @question.fetch(:key) }
    destination = case navigation
                  when "review"
                    review_adaptive_project_intake_quiz_path(@intake)
                  when "intake"
                    project_intake_path(@intake)
                  when "back"
                    previous = @questions[[position - 1, 0].max]
                    adaptive_project_intake_quiz_path(@intake, step: previous.fetch(:key))
                  else
                    following = @questions[position + 1]
                    following ? adaptive_project_intake_quiz_path(@intake, step: following.fetch(:key)) :
                                review_adaptive_project_intake_quiz_path(@intake)
                  end
    redirect_to destination, notice: "Adaptive quiz draft saved"
  end

  def review
    refresh_questions
    @unfinished_question = @questions.find { |question| !@saved_answers.key?(question.fetch(:key)) }
  end

  private

  def require_owner!
    return if owner_signed_in?

    redirect_to sign_in_path, alert: "Owner sign-in required"
  end

  def set_intake
    @intake = ProjectIntake.find(params[:project_intake_id])
    if @intake.workspace_id.present? && !@intake.workspace.owner_access?(current_user)
      head :not_found
    end
  end

  def refresh_questions
    @intake.intake_answers.reset
    raw = @intake.intake_answers.to_a.index_by(&:question_key)
    @questions = Intake::AdaptiveQuestionCatalog.for(@intake.project_type, answers: raw)
    visible_keys = @questions.map { |question| question.fetch(:key) }
    @saved_answers = raw.slice(*visible_keys)
    # Hidden answers remain in PostgreSQL with their revisions intact, but
    # cannot be edited or counted as current requirements while their parent
    # condition is no longer met.
    @hidden_saved_count = raw.count do |key, _|
      Intake::AdaptiveQuestionCatalog.definition(@intake.project_type, key) && !visible_keys.include?(key)
    end
  end

  def newly_hidden_saved_count
    proposed = @intake.intake_answers.to_a.index_by(&:question_key)
    proposed[@question.fetch(:key)] = { "selected_options" => @answer.selected_options }
    after_keys = Intake::AdaptiveQuestionCatalog.for(@intake.project_type, answers: proposed)
                                                .map { |entry| entry.fetch(:key) }
    @saved_answers.keys.count { |key| !after_keys.include?(key) }
  end

  def quiz_params
    params.require(:quiz).permit(:revision, :other_text, :comment, :unsure,
                                 :navigation, :confirm_branch_change,
                                 selected_options: [], feature_priorities: {})
  end
end
