# C2.1c: owner-only persisted conversations with explicitly consented, ledgered AI turns.
class OwnerAiConversationsController < ApplicationController
  before_action :require_owner!
  before_action :load_workspace
  before_action :load_conversation, only: %i[show add_message rename archive]
  before_action :load_lists, only: %i[index show]

  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def index
  end

  def show
    @messages = @conversation.owner_ai_messages.includes(:ai_spend_entry).in_order
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
    intent = params[:intent].presence || "note"
    unless body.length.between?(1, 1200) && request_id.match?(UUID_PATTERN) &&
           %w[note ai].include?(intent)
      return redirect_to owner_ai_conversation_path(@conversation),
                         alert: t("owner_ai_conversations.invalid_message")
    end
    if intent == "ai"
      return redirect_to owner_ai_conversation_path(@conversation),
                         alert: t("owner_ai_conversations.consent_required") unless params[:paid_consent] == "1"
      return redirect_to owner_ai_conversation_path(@conversation),
                         alert: t("owner_ai_conversations.ai_disabled") unless OwnerIntelligence::Grok.enabled?
    end

    outcome = nil
    owner_message = nil
    assistant_message = nil
    @conversation.with_lock do
      existing = @conversation.owner_ai_messages.find_by(request_id: request_id)
      if existing
        is_paid_turn = @conversation.owner_ai_messages.exists?(parent_message_id: existing.id, role: "assistant")
        outcome = existing.owner_message? && existing.body == body &&
          (intent == "ai") == is_paid_turn ? :replay : :conflict
      elsif @conversation.archived?
        outcome = :archived
      elsif intent == "ai" && @conversation.owner_ai_messages.exists?(role: "assistant", state: %w[pending uncertain])
        outcome = :busy
      else
        next_sequence = @conversation.owner_ai_messages.maximum(:sequence).to_i + 1
        owner_message = @conversation.owner_ai_messages.create!(
          role: "owner", state: intent == "ai" ? "pending" : "draft",
          sequence: next_sequence, request_id: request_id, body: body
        )
        if intent == "ai"
          assistant_message = @conversation.owner_ai_messages.create!(
            role: "assistant", state: "pending", sequence: next_sequence + 1,
            parent_message: owner_message, body: "-"
          )
          defaults = I18n.available_locales.map do |locale|
            I18n.t("owner_ai_conversations.default_title", locale: locale)
          end
          if next_sequence == 1 && defaults.include?(@conversation.title)
            @conversation.update!(title: body.truncate(80, omission: "…"))
          end
        end
        @conversation.touch
        outcome = :created
      end
    end

    if outcome == :created && intent == "ai"
      begin
        OwnerAi::ConversationResponder.new(workspace: @workspace).reply!(
          owner_message: owner_message, assistant_message: assistant_message, paid_consent: true
        )
        outcome = :ai_ready
      rescue OwnerAi::ConversationResponder::Unavailable
        outcome = :ai_failed
      end
    end

    case outcome
    when :created
      redirect_to owner_ai_conversation_path(@conversation), notice: t("owner_ai_conversations.saved")
    when :ai_ready
      redirect_to owner_ai_conversation_path(@conversation), notice: t("owner_ai_conversations.ai_ready")
    when :ai_failed
      redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.ai_failed")
    when :replay
      redirect_to owner_ai_conversation_path(@conversation), notice: t("owner_ai_conversations.replayed")
    when :archived
      redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.read_only")
    when :busy
      redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.ai_busy")
    else
      redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.request_conflict")
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StaleObjectError
    redirect_to owner_ai_conversation_path(@conversation), alert: t("owner_ai_conversations.save_failed")
  end

  def rename
    title = params[:title].is_a?(String) ? params[:title].strip : ""
    unless title.length.between?(1, 100)
      return redirect_to owner_ai_conversation_path(@conversation),
                         alert: t("owner_ai_conversations.invalid_title")
    end
    updated = false
    @conversation.with_lock do
      unless @conversation.archived?
        @conversation.update!(title: title)
        updated = true
      end
    end
    redirect_to owner_ai_conversation_path(@conversation),
                (updated ? { notice: t("owner_ai_conversations.renamed") } :
                           { alert: t("owner_ai_conversations.read_only") })
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
    @ai_enabled = OwnerIntelligence::Grok.enabled?
  end
end
