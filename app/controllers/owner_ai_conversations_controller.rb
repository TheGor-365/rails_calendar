# C2.1c: owner-only persisted conversations with explicitly consented, ledgered AI turns.
class OwnerAiConversationsController < ApplicationController
  before_action :require_owner!
  before_action :load_workspace
  before_action :load_conversation, only: %i[show add_message rename archive restore remove file]
  before_action :load_lists, only: %i[index show]

  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  MAX_FILES = 3
  FILE_TYPES = {
    "image/jpeg" => %w[.jpg .jpeg],
    "image/png" => %w[.png],
    "image/webp" => %w[.webp],
    "text/plain" => %w[.txt .md .markdown .log .csv .json .rb .py .js .ts .yml .yaml .xml .css .scss .sql .sh],
    "text/markdown" => %w[.md .markdown],
    "text/csv" => %w[.csv],
    "application/json" => %w[.json],
    "application/pdf" => %w[.pdf],
    "application/zip" => %w[.zip .docx .xlsx .pptx],
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => %w[.docx],
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => %w[.xlsx],
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" => %w[.pptx],
    "application/x-7z-compressed" => %w[.7z],
    "application/x-rar-compressed" => %w[.rar],
    "application/vnd.rar" => %w[.rar],
    "application/gzip" => %w[.gz],
    "application/x-tar" => %w[.tar]
  }.freeze
  # Stored files are never executed. Model sees only explicitly consented image/text.
  AI_FILE_TYPES = %w[image/jpeg image/png text/plain text/markdown text/csv application/json].freeze

  def index
    if (latest = @active_conversations.first)
      return redirect_to owner_ai_conversation_path(latest)
    end
  end

  def show
    @messages = @conversation.owner_ai_messages.includes(:ai_spend_entry, files_attachments: :blob).in_order
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
    uploads = Array(params[:files]).reject(&:blank?)
    body = t("owner_ai_conversations.file_only_message") if intent == "note" && body.blank? && uploads.any?
    unless body.length.between?(1, 1200) && request_id.match?(UUID_PATTERN) &&
           %w[note ai].include?(intent)
      return render_message_error("owner_ai_conversations.invalid_message")
    end
    return render_message_error("owner_ai_conversations.invalid_file") unless valid_files?(uploads, intent: intent)
    if intent == "ai"
      return render_message_error("owner_ai_conversations.consent_required") unless params[:paid_consent] == "1"
      return render_message_error("owner_ai_conversations.ai_disabled") unless OwnerIntelligence::Grok.enabled?
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
      elsif !@conversation.active?
        outcome = :archived
      elsif intent == "ai" && @conversation.owner_ai_messages.exists?(role: "assistant", state: %w[pending uncertain])
        outcome = :busy
      else
        next_sequence = @conversation.owner_ai_messages.maximum(:sequence).to_i + 1
        owner_message = @conversation.owner_ai_messages.create!(
          role: "owner", state: intent == "ai" ? "pending" : "draft",
          sequence: next_sequence, request_id: request_id, body: body
        )
        owner_message.files.attach(uploads) if uploads.any?
        if intent == "ai"
          assistant_message = @conversation.owner_ai_messages.create!(
            role: "assistant", state: "pending", sequence: next_sequence + 1,
            parent_message: owner_message, body: "-"
          )
        end
        defaults = I18n.available_locales.map do |locale|
          I18n.t("owner_ai_conversations.default_title", locale: locale)
        end
        if next_sequence == 1 && defaults.include?(@conversation.title)
          auto_name = body.truncate(80, omission: "…")
          auto_name = uploads.first.original_filename.truncate(80) if intent == "note" &&
            body == t("owner_ai_conversations.file_only_message") && uploads.any?
          @conversation.update!(title: auto_name)
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

  # Only the authenticated Owner can fetch private attached bytes; never expose
  # Active Storage signed/public blob URLs or accept a filename path parameter.
  def file
    message = @conversation.owner_ai_messages.find_by(id: params[:message_id], role: "owner")
    return head :not_found unless message

    attachment = message.files_attachments.find_by(id: params[:attachment_id])
    return head :not_found unless attachment

    blob = attachment.blob
    return head :not_found unless FILE_TYPES.key?(blob.content_type)

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    image = blob.content_type.in?(%w[image/png image/jpeg image/webp])
    send_data blob.download, type: image ? blob.content_type : "application/octet-stream",
              disposition: image ? "inline" : "attachment",
              filename: blob.filename.to_s
  rescue ActiveStorage::FileNotFoundError
    head :not_found
  end

  # Optimistic in-place rename used by Stimulus; still works via HTML form fallback.
  def rename
    title = params[:title].is_a?(String) ? params[:title].strip : ""
    if !title.length.between?(1, 100) || @conversation.removed? || @conversation.archived?
      return render json: { error: t("owner_ai_conversations.invalid_title") },
                    status: :unprocessable_entity if request.format.json?
      return redirect_to owner_ai_conversation_path(@conversation),
                         alert: t("owner_ai_conversations.invalid_title")
    end
    @conversation.with_lock { @conversation.update!(title: title) }
    return render json: { title: @conversation.title } if request.format.json?

    redirect_to owner_ai_conversation_path(@conversation), notice: t("owner_ai_conversations.renamed")
  end

  def archive
    @conversation.archive!
    redirect_to owner_ai_conversation_path(@conversation), notice: t("owner_ai_conversations.archived")
  end

  def restore
    @conversation.restore!
    redirect_to owner_ai_conversation_path(@conversation), notice: t("owner_ai_conversations.restored")
  end

  # 'Delete' is reversible: hide from normal lists, preserve evidence and charges.
  def remove
    @conversation.remove!
    redirect_to owner_ai_conversations_path, notice: t("owner_ai_conversations.removed")
  end

  private

  def valid_files?(uploads, intent:)
    return false if uploads.length > MAX_FILES

    uploads.all? do |upload|
      next false unless upload.respond_to?(:tempfile) &&
        upload.respond_to?(:original_filename) && upload.size.positive?
      mime = upload.content_type.to_s.downcase
      extension = File.extname(upload.original_filename.to_s).downcase
      next false unless FILE_TYPES.fetch(mime, []).include?(extension)
      next false if intent == "ai" && !AI_FILE_TYPES.include?(mime)
      bytes_limit = case mime
      when "image/jpeg", "image/png", "image/webp" then 2.megabytes
      when "application/pdf" then 10.megabytes
      when "application/zip", "application/x-7z-compressed", "application/x-rar-compressed",
           "application/vnd.rar", "application/gzip", "application/x-tar",
           "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
           "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
           "application/vnd.openxmlformats-officedocument.presentationml.presentation" then 15.megabytes
      else 24.kilobytes
      end
      next false if upload.size > bytes_limit
      sniffed = Marcel::MimeType.for(upload.tempfile, name: upload.original_filename)
      sniffed == mime ||
        (mime.in?(%w[text/markdown text/csv application/json]) && sniffed == "text/plain") ||
        (mime == "text/plain" && sniffed.in?(%w[text/markdown text/csv application/json])) ||
        (mime.start_with?("application/vnd.openxmlformats") && sniffed == "application/zip")
    end
  end

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
    @removed_conversations = @workspace.owner_ai_conversations.where(state: "removed").recent_first
    @ai_enabled = OwnerIntelligence::Grok.enabled?
  end

  # Keep the owner's unsent prompt and UUID when consent/config validation fails.
  # Redirecting here would silently erase the text before a paid request begins.
  def render_message_error(translation_key)
    @draft_body = params[:body].is_a?(String) ? params[:body] : ""
    submitted_id = params[:request_id].is_a?(String) ? params[:request_id] : ""
    @draft_request_id = submitted_id.match?(UUID_PATTERN) ? submitted_id : SecureRandom.uuid
    @draft_paid_consent = params[:paid_consent] == "1"
    @messages = @conversation.owner_ai_messages.includes(:ai_spend_entry, files_attachments: :blob).in_order
    load_lists
    flash.now[:alert] = t(translation_key)
    render :index, status: :unprocessable_entity
  end
end
