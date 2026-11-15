class CreateServiceOfferingMediaItems < ActiveRecord::Migration[8.1]
  def change
    # The repository previously configured Active Storage but had no backing
    # tables. Use the standard Rails polymorphic attachment structure.
    create_table :active_storage_blobs do |t|
      t.string :key, null: false
      t.string :filename, null: false
      t.string :content_type
      t.text :metadata
      t.string :service_name, null: false
      t.bigint :byte_size, null: false
      t.string :checksum
      t.datetime :created_at, precision: 6, null: false
      t.index :key, unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string :name, null: false
      t.references :record, null: false, polymorphic: true, index: false
      t.references :blob, null: false, foreign_key: { to_table: :active_storage_blobs }
      t.datetime :created_at, precision: 6, null: false
      t.index %i[record_type record_id name blob_id], unique: true,
              name: "index_active_storage_attachments_uniqueness"
    end

    create_table :active_storage_variant_records do |t|
      t.references :blob, null: false, foreign_key: { to_table: :active_storage_blobs }, index: false
      t.string :variation_digest, null: false
      t.index %i[blob_id variation_digest], unique: true,
              name: "index_active_storage_variant_records_uniqueness"
    end

    create_table :service_offering_media_items do |t|
      t.references :service_offering, null: false, foreign_key: true,
                   index: { name: "idx_offering_media_offering" }
      t.references :service_offering_version, null: false, foreign_key: true,
                   index: { name: "idx_offering_media_source_version" }
      t.references :uploaded_by_user, null: false, foreign_key: { to_table: :users },
                   index: { name: "idx_offering_media_uploader" }
      t.string :media_kind, null: false, limit: 20
      t.string :caption, null: false, default: "", limit: 160
      t.datetime :approved_at
      t.datetime :archived_at
      # No service or AI integration may read the file until explicit opt-in
      # is implemented in a later, separately reviewed stage.
      t.boolean :ai_access_allowed, null: false, default: false
      t.timestamps
    end

    add_check_constraint :service_offering_media_items,
                         "media_kind IN ('banner','image','document','audio','video')",
                         name: "chk_offering_media_kind"
    add_check_constraint :service_offering_media_items, "char_length(caption) <= 160",
                         name: "chk_offering_media_caption"
    add_index :service_offering_media_items, %i[service_offering_id archived_at created_at],
              name: "idx_offering_media_visible"
  end
end
