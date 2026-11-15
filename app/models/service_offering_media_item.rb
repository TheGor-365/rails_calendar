class ServiceOfferingMediaItem < ApplicationRecord
  KINDS = %w[banner image document audio video].freeze
  ALLOWED_MIME_TYPES = {
    "banner" => %w[image/jpeg image/png image/webp],
    "image" => %w[image/jpeg image/png image/webp image/gif],
    "document" => %w[application/pdf text/plain],
    "audio" => %w[audio/mpeg audio/ogg audio/wav audio/x-wav audio/mp4],
    "video" => %w[video/mp4 video/webm]
  }.freeze
  ALLOWED_EXTENSIONS = {
    "image/jpeg" => %w[.jpg .jpeg],
    "image/png" => %w[.png],
    "image/webp" => %w[.webp],
    "image/gif" => %w[.gif],
    "application/pdf" => %w[.pdf],
    "text/plain" => %w[.txt .md],
    "audio/mpeg" => %w[.mp3],
    "audio/ogg" => %w[.ogg .oga],
    "audio/wav" => %w[.wav],
    "audio/x-wav" => %w[.wav],
    "audio/mp4" => %w[.m4a],
    "video/mp4" => %w[.mp4],
    "video/webm" => %w[.webm]
  }.freeze
  MAX_FILE_SIZE = {
    "banner" => 8.megabytes, "image" => 8.megabytes,
    "document" => 10.megabytes, "audio" => 20.megabytes,
    "video" => 25.megabytes
  }.freeze

  belongs_to :service_offering
  belongs_to :service_offering_version
  belongs_to :uploaded_by_user, class_name: "User"
  has_one_attached :file

  validates :media_kind, inclusion: { in: KINDS }
  validates :caption, length: { maximum: 160 }
  validate :validate_source_and_uploader
  validate :validate_file_content
  validate :approved_record_is_immutable, on: :update

  scope :visible, -> { where(archived_at: nil).order(created_at: :desc, id: :desc) }

  def approved?
    approved_at.present?
  end

  def image?
    %w[banner image].include?(media_kind)
  end

  def can_be_processed_by_ai?
    # File bytes never leave the server until a separate consent + safety
    # review and provider integration is explicitly implemented.
    false
  end

  private

  def validate_source_and_uploader
    return if service_offering.nil?
    if service_offering_version && service_offering_version.service_offering_id != service_offering_id
      errors.add(:service_offering_version, "must belong to this offering")
    end
    if uploaded_by_user && service_offering.workspace.owner_user_id != uploaded_by_user.id
      errors.add(:uploaded_by_user, "must own this offering")
    end
  end

  def validate_file_content
    unless file.attached?
      errors.add(:file, "is required")
      return
    end
    blob = file.blob
    return if blob.nil? || !KINDS.include?(media_kind)

    content_type = blob.content_type.to_s.downcase
    unless ALLOWED_MIME_TYPES.fetch(media_kind).include?(content_type)
      errors.add(:file, "has an unsupported type for this category")
      return
    end

    filename_extension = File.extname(blob.filename.to_s).downcase
    unless ALLOWED_EXTENSIONS.fetch(content_type, []).include?(filename_extension)
      errors.add(:file, "extension does not match the permitted type")
    end
    if blob.byte_size.to_i <= 0 || blob.byte_size.to_i > MAX_FILE_SIZE.fetch(media_kind)
      errors.add(:file, "exceeds the allowed size for this category")
    end
  end

  def approved_record_is_immutable
    return unless approved_at_in_database.present?

    changed = changes_to_save.keys - %w[archived_at updated_at]
    errors.add(:base, "approved media cannot be changed; upload a new revision") if changed.any?
  end
end
