# frozen_string_literal: true

# Phase 2: Automatic link verification
class CreateApkVerifications < ActiveRecord::Migration[7.0]
  def change
    create_table :apk_verifications do |t|
      t.integer :topic_id, null: false

      # HTTP availability check
      # "available" = HTTP 200-299
      # "unavailable" = any other status or error
      t.string :availability_status, default: "unknown"
      t.string :availability_description

      # Checksum consistency check
      # "consistent" = current checksum matches stored checksum
      # "inconsistent" = checksums differ or cannot be computed
      t.string :consistency_status, default: "unknown"
      t.string :consistency_description

      # The checksum computed during last verification
      t.string :last_computed_checksum

      # HTTP status code from last check
      t.integer :last_http_status

      t.datetime :last_checked_at

      t.timestamps
    end

    add_index :apk_verifications, :topic_id, unique: true
    add_index :apk_verifications, :availability_status
    add_index :apk_verifications, :consistency_status
  end
end
