module Admin
  class ProjectIntakesController < ApplicationController
    before_action :require_admin!
    before_action :set_intake, only: %i[draft_spec approve_spec]

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

    private

    def set_intake
      @intake = ProjectIntake.find(params[:id])
    end
  end
end
