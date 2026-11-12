module Admin
  class ProjectIntakesController < ApplicationController
    before_action :require_admin!
    before_action :set_intake, only: %i[draft_spec approve_spec edit_spec revise_spec plan]

    def index
      @intakes = ProjectIntake.order(created_at: :desc, id: :desc).limit(50)
    end

    def draft_spec
      return head :conflict if @intake.client_message_count.zero?

      content, source = Intake::Grok.new(@intake).draft_spec
      @intake.with_lock do
        version = @intake.intake_spec_versions.maximum(:version).to_i + 1
        @intake.intake_spec_versions.create!(
          version: version, document: content, source: source
        )
        @intake.update!(status: "draft_spec")
      end
      redirect_to project_intake_path(@intake),
                  notice: I18n.t("intake.flash_spec_drafted", source: source == "grok" ? "Grok" : "Demo template")
    end

    def approve_spec
      spec = @intake.latest_spec
      return head :conflict unless spec && @intake.status == "draft_spec"

      spec.update!(owner_approved_at: Time.current)
      @intake.update!(status: "owner_approved")
      redirect_to project_intake_path(@intake),
                  notice: I18n.t("intake.flash_spec_approved", version: spec.version)
    end

    def edit_spec
      @spec = @intake.latest_spec
      return head :conflict unless @spec && @intake.status == "draft_spec" && !@spec.approved?
    end

    def revise_spec
      expected_version = params[:expected_version].to_s
      return head :conflict unless expected_version.match?(/\A[1-9]\d{0,8}\z/)

      # Human review creates a NEW revision. Previous versions remain unchanged
      # and retain their original AI/template attribution and publication dates.
      revised = build_revised_document
      return render_invalid_review(revised) unless revised

      outcome = @intake.with_lock do
        current = @intake.latest_spec
        if @intake.status != "draft_spec" || current.nil? ||
           current.approved? || current.version != expected_version.to_i
          :conflict
        else
          version = @intake.intake_spec_versions.new(
            version: current.version + 1,
            source: "human",
            document: revised
          )
          if version.save
            :saved
          else
            @review_errors = version.errors.full_messages
            :invalid
          end
        end
      end

      case outcome
      when :saved
        redirect_to project_intake_path(@intake), notice: I18n.t("intake.flash_revised")
      when :conflict
        head :conflict
      else
        @spec = @intake.latest_spec
        render :edit_spec, status: :unprocessable_entity
      end
    end

    # A human picks a tentative start date. Durations are only proposed by
    # the reviewed spec. Every schedule is private to this intake.
    def plan
      spec = @intake.latest_spec
      return head :conflict unless spec&.approved? && %w[owner_approved client_reviewed].include?(@intake.status)
      return head :unprocessable_entity unless params[:confirm_plan] == "1"

      start = Date.iso8601(params[:start_date].to_s)
      return head :unprocessable_entity unless start.year.between?(2000, 2100)

      phases = spec.document["milestones"]
      return head :unprocessable_entity unless phases.is_a?(Array) && phases.length.between?(1, 6)
      return head :unprocessable_entity unless phases.all? do |phase|
        phase.is_a?(Hash) &&
          phase["title"].is_a?(String) && phase["title"].length.between?(1, 100) &&
          phase["description"].is_a?(String) && phase["description"].length.between?(1, 240) &&
          phase["suggested_work_days"].is_a?(Integer) &&
          phase["suggested_work_days"].between?(1, 30)
      end

      @intake.with_lock do
        return head :conflict if @intake.project_milestones.exists?

        next_day = next_work_day(start)
        phases.each_with_index do |phase, position|
          first_day = next_day
          last_day = first_day
          (phase.fetch("suggested_work_days") - 1).times { last_day = next_work_day(last_day + 1.day) }

          @intake.project_milestones.create!(
            intake_spec_version: spec,
            position: position + 1,
            title: phase.fetch("title"),
            description: phase.fetch("description"),
            suggested_work_days: phase.fetch("suggested_work_days"),
            start_on: first_day, end_on: last_day, status: "proposed"
          )
          next_day = next_work_day(last_day + 1.day)
        end
      end
      redirect_to project_intake_path(@intake),
                  notice: I18n.t("intake.flash_plan_created")
    rescue Date::Error, TypeError
      head :unprocessable_entity
    end

    private

    def next_work_day(date)
      day = date
      day += 1.day while day.saturday? || day.sunday?
      day
    end

    SECTION_LIMITS = {
      "goals" => 8,
      "deliverables" => 12,
      "acceptance_criteria" => 12,
      "unknowns" => 10,
      "exclusions" => 10
    }.freeze

    def build_revised_document
      form = params.require(:review).permit(:summary, *SECTION_LIMITS.keys.map(&:to_sym))
      summary = form[:summary].to_s.strip
      return nil if summary.blank? || summary.length > 1200

      source_document = @intake.latest_spec&.document
      return nil unless source_document.is_a?(Hash)

      document = source_document.deep_dup
      document["summary"] = summary
      SECTION_LIMITS.each do |key, max_items|
        raw = form[key].to_s
        return nil if raw.length > 5000

        lines = raw.split(/\r?\n/).map(&:strip).reject(&:blank?)
        return nil if lines.length > max_items || lines.any? { |line| line.length > 250 }
        document[key] = lines
      end
      document
    end

    def render_invalid_review(_revised)
      @spec = @intake.latest_spec
      @review_errors = [I18n.t("intake.flash_invalid_review")]
      render :edit_spec, status: :unprocessable_entity
    end

    def set_intake
      @intake = ProjectIntake.find(params[:id])
    end
  end
end
