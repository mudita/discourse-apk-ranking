# frozen_string_literal: true

class AddVersionUpdatedAtToApkReviews < ActiveRecord::Migration[7.0]
  def up
    add_column :apk_reviews, :version_updated_at, :datetime

    # Every review edit leaves an audit post listing the changed fields, so the
    # newest one mentioning Version or Checksum dates the last update.
    execute <<~SQL
      UPDATE apk_reviews
      SET version_updated_at = audits.updated_at
      FROM (
        SELECT posts.topic_id, MAX(posts.created_at) AS updated_at
        FROM posts
        INNER JOIN post_custom_fields ON post_custom_fields.post_id = posts.id
        WHERE post_custom_fields.name = 'apk_audit_raw'
          AND posts.deleted_at IS NULL
          AND (
            post_custom_fields.value LIKE '%**Version**:%'
            OR post_custom_fields.value LIKE '%**Checksum**:%'
          )
        GROUP BY posts.topic_id
      ) audits
      WHERE audits.topic_id = apk_reviews.topic_id
    SQL
  end

  def down
    remove_column :apk_reviews, :version_updated_at
  end
end
