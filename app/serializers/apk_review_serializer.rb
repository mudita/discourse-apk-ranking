# frozen_string_literal: true

class ::ApkReviewSerializer < ::ApplicationSerializer
  attributes :id,
             :topic_id,
             :user_id,
             :username,
             :app_name,
             :app_category,
             :apk_link,
             :apk_version,
             :author_rating,
             :app_description,
             :known_issues,
             :screenshot_urls,
             :apk_checksum,
             :last_access_date,
             :community_average,
             :community_count,
             :author_is_developer,
             :icon_url,
             :created_at,
             :updated_at

  def icon_url
    url = object.topic&.custom_fields&.dig("apk_icon_url").to_s.strip
    url.presence
  end

  def username
    object.user&.username
  end

  def community_average
    community_data[:average]
  end

  def community_count
    community_data[:count]
  end

  def author_is_developer
    object.topic&.custom_fields&.dig("apk_author_is_developer") == "true"
  end

  private

  def community_data
    @community_data ||= ApkReview.community_rating_for(object.topic_id)
  end
end
