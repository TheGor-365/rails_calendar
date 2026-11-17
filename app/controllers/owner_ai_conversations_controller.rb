# C2.1b: owner-only persisted conversations. No AI/provider or ledger calls.
class OwnerAiConversationsController < ApplicationController
  before_action :require_owner!
  before_action :load_workspace
  before_action :load_conversation, only: %i[show add_message archive]
  before_action :load_lists, only: %i[index show]

  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def index
  end

  def show
    @messages = @conversation.owner_ai_messages.in_order
    render :index
  end

  def create
    title = params[:title].is_a?(String) ? params[:title].strip : ""
    title = t("owner_ai_conversations.default_title") if title.blank?
    conversation = @workspace.owner_ai_conversations.new(title: title)
    if conversation.save
      redirect_to owner_ai_conversation_path(conversation), notice: t("owner_ai_conversations.created")
    else
      redirect_to owner_ai_conversations_path, alert: t("owner_ai_conversations.invalid_title")
    end
  end

  def add_message
    body = params[:body].is_a?(String) ? params[:body].strip : ""
    request_id = params[:request_id].is_a?(String) ? params[:request_id] : ""
    unless body.length.between?(1, 1200) && request_id.match?(UUID_PATTERN)
      return redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.invalid_message")
    end

    outcome = nil
    # Lock the parent row so archiving and sequence allocation serialize.
    # A repeated form submission with the same UUID never stores a second record.
    @conversation.with_lock do
      existing = @conversation.owner_ai_messages.find_by(request_id: request_id)
      if existing
        outcome = existing.owner_message? && existing.body == body ? :replay : :conflict
      elsif @conversation.archived?
        outcome = :archived
      else
        next_sequence = @conversation.owner_ai_messages.maximum(:sequence).to_i + 1
        @conversation.owner_ai_messages.create!(
          role: "owner", state: "draft", sequence: next_sequence,
          request_id: request_id, body: body
        )
        @conversation.touch
        outcome = :created
      end
    end

    case outcome
    when :created, :replay
      redirect_to owner_ai_conversation_path(@conversation), notice: t("owner_ai_conversations.saved")
    when :archived
      redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.read_only")
    else
      redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.request_conflict")
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.save_failed")
  end

  def archive
    @conversation.archive!
    redirect_to owner_ai_conversation_path(@conversation), notice: t("owner_ai_conversations.archived")
  end

  private

  def require_owner!
    redirect_to sign_in_path, alert: t("owner_setup.owner_only") unless owner_signed_in?
  end

  def load_workspace
    @workspace = current_user.owner_workspace || current_user.create_owner_workspace!
  end

  def load_conversation
    @conversation = @workspace.owner_ai_conversations.find_by(id: params[:id])
    head :not_found unless @conversation
  end

  def load_lists
    @active_conversations = @workspace.owner_ai_conversations.where(state: "active").recent_first
    @archived_conversations = @workspace.owner_ai_conversations.where(state: "archived").recent_first
  end
end
