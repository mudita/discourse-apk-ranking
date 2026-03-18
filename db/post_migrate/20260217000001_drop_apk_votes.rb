# frozen_string_literal: true

class DropApkVotes < ActiveRecord::Migration[7.0]
  def up
    drop_table :apk_votes if table_exists?(:apk_votes)
  end

  def down
    create_table :apk_votes do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.integer :vote_type, null: false
      t.timestamps
    end

    add_index :apk_votes, %i[user_id topic_id], unique: true
    add_index :apk_votes, :topic_id
    add_index :apk_votes, %i[topic_id vote_type]
  end
end
