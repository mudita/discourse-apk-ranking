# frozen_string_literal: true

class AddLinkTypeToApkVerifications < ActiveRecord::Migration[7.0]
  def change
    add_column :apk_verifications, :link_type, :string, default: nil
  end
end
