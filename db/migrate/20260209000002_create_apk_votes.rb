# frozen_string_literal: true

class CreateApkVotes < ActiveRecord::Migration[7.0]
  def change
    create_table :apk_votes do |t|
      t.integer :user_id,   null: false
      t.integer :topic_id,  null: false

      # 1 = positive (thumbs up), -1 = negative (thumbs down)
      t.integer :vote_type, null: false

      t.timestamps
    end

    # Each user can only vote once per topic
    add_index :apk_votes, [:user_id, :topic_id], unique: true
    add_index :apk_votes, :topic_id
    add_index :apk_votes, [:topic_id, :vote_type]
  end
end
