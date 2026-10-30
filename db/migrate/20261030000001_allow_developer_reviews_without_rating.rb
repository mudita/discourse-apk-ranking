# frozen_string_literal: true

class AllowDeveloperReviewsWithoutRating < ActiveRecord::Migration[7.0]
  def up
    change_column_null :apk_reviews, :author_rating, true

    # The submitted value stays in the apk_author_rating topic custom field.
    execute <<~SQL
      UPDATE apk_reviews
      SET author_rating = NULL
      WHERE topic_id IN (
        SELECT topic_id FROM topic_custom_fields
        WHERE name = 'apk_author_is_developer' AND value = 'true'
      )
    SQL
  end

  def down
    execute <<~SQL
      UPDATE apk_reviews
      SET author_rating = COALESCE(
        (
          SELECT NULLIF(value, '')::integer FROM topic_custom_fields
          WHERE topic_custom_fields.topic_id = apk_reviews.topic_id
            AND name = 'apk_author_rating'
          LIMIT 1
        ),
        3
      )
      WHERE author_rating IS NULL
    SQL

    change_column_null :apk_reviews, :author_rating, false
  end
end
