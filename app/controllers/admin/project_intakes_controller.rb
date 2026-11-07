module Admin
  class ProjectIntakesController < ApplicationController
    before_action :require_admin!
    before_action :set_intake, only: %i[draft_spec approve_spec plan]

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
                  notice: "#{source == 'grok' ? 'Grok' : 'Demo template'} specification drafted for administrator review"
    end

    def approve_spec
      spec = @intake.latest_spec
      return head :conflict unless spec && @intake.status == "draft_spec"

      spec.update!(owner_approved_at: Time.current)
      @intake.update!(status: "owner_approved")
      redirect_to project_intake_path(@intake),
                  notice: "Version #{spec.version} approved by administrator; commercial terms and dates remain unconfirmed"
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
                  notice: "Tentative project calendar created; dates and capacity are not client commitments"
    rescue Date::Error, TypeError
      head :unprocessable_entity
    end

    private

    def next_work_day(date)
      day = date
      day += 1.day while day.saturday? || day.sunday?
      day
    end

    def set_intake
      @intake = ProjectIntake.find(params[:id])
    end
  end
end
