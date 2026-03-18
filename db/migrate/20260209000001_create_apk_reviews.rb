# frozen_string_literal: true

class CreateApkReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :apk_reviews do |t|
      # Link to Discourse topic (one review per topic)
      t.integer :topic_id, null: false
      t.integer :user_id, null: false

      # App information
      t.string  :app_name,        null: false
      t.string  :app_category,    null: false
      t.string  :apk_link,        null: false
      t.string  :apk_version,     null: false

      # Author's star rating (1-5)
      t.integer :author_rating,   null: false

      # Descriptions (stored as text for longer content)
      t.text    :app_description
      t.text    :known_issues

      # Screenshot URLs (stored as JSON array)
      t.json    :screenshot_urls, default: []

      # Verification tracking
      t.string  :apk_checksum             # SHA-256 hash at time of submission
      t.datetime :last_access_date         # Date when file was last verified accessible

      t.timestamps
    end

    add_index :apk_reviews, :topic_id, unique: true
    add_index :apk_reviews, :user_id
    add_index :apk_reviews, :app_name
    add_index :apk_reviews, :app_category
    add_index :apk_reviews, :author_rating
  end
end
