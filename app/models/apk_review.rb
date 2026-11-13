# frozen_string_literal: true

class ::ApkReview < ActiveRecord::Base
  self.table_name = "apk_reviews"

  belongs_to :topic, class_name: "::Topic"
  belongs_to :user, class_name: "::User"
  has_one :verification,
          class_name: "::ApkVerification",
          foreign_key: :topic_id,
          primary_key: :topic_id

  validates :topic_id, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :app_name, presence: true, length: { maximum: 255 }
  validates :app_category, presence: true, length: { maximum: 100 }
  validates :apk_link,
            presence: true,
            format: {
              with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
            }
  validates :apk_version, presence: true, length: { maximum: 50 }
  validates :author_rating, inclusion: { in: 1..5 }, unless: :author_is_developer?
  validates :author_rating, absence: true, if: :author_is_developer?
  validates :app_description, presence: true

  APP_CATEGORIES = %w[
    communication
    social
    productivity
    utilities
    tools
    health
    finance
    entertainment
    music
    navigation
    weather
    news
    education
    other
  ].freeze

  def self.app_categories
    APP_CATEGORIES
  end

  # A developer reviewing their own app does not rate it; anyone else must.
  def self.author_rating_from(custom_fields)
    return nil if custom_fields["apk_author_is_developer"] == "true"
    (custom_fields["apk_author_rating"].presence || 3).to_i.clamp(1, 5)
  end

  def author_is_developer?
    topic&.custom_fields&.dig("apk_author_is_developer") == "true"
  end

  # Single source for community ratings: the topic list, the sort order and
  # the topic page all read this, so the shown value and the rank never drift.
  # One rating per (topic, user). Reply ratings are written to both stores and
  # the PluginStore row wins (users who rated before the PluginStore existed
  # only have the reply field), so a reply is never counted twice. Topics
  # without an ApkReview (info posts) never get a rating.
  def self.community_stats_sql
    <<~SQL
      SELECT deduped.topic_id,
             ROUND(AVG(deduped.rating), 1) AS community_avg,
             COUNT(*) AS community_count,
             SUM(deduped.rating) AS community_sum
      FROM (
        SELECT DISTINCT ON (topic_id, user_id) topic_id, user_id, rating
        FROM (
          SELECT SUBSTRING(key FROM 't(\\d+)_u')::integer AS topic_id,
                 SUBSTRING(key FROM 't\\d+_u(\\d+)')::integer AS user_id,
                 value::integer AS rating,
                 0 AS source_priority
          FROM plugin_store_rows
          WHERE plugin_name = 'sideloaded_ratings'
          UNION ALL
          SELECT posts.topic_id, posts.user_id,
                 post_custom_fields.value::integer AS rating,
                 1 AS source_priority
          FROM post_custom_fields
          INNER JOIN posts ON posts.id = post_custom_fields.post_id
          WHERE post_custom_fields.name = 'apk_rating'
            AND posts.deleted_at IS NULL
            AND posts.post_number > 1
        ) sources
        ORDER BY topic_id, user_id, source_priority
      ) deduped
      INNER JOIN apk_reviews ON apk_reviews.topic_id = deduped.topic_id
      WHERE deduped.rating BETWEEN 1 AND 5
      GROUP BY deduped.topic_id
    SQL
  end

  def self.community_stats_for(topic_ids)
    ids = Array(topic_ids).map(&:to_i)
    return {} if ids.empty?

    DB
      .query(<<~SQL, ids: ids)
        SELECT stats.*, #{community_score_sql("stats")} AS community_score
        FROM (#{community_stats_sql}) stats
        WHERE topic_id IN (:ids)
      SQL
      .to_h do |row|
        [
          row.topic_id,
          {
            average: row.community_score.to_f,
            plain_average: row.community_avg.to_f,
            count: row.community_count,
          },
        ]
      end
  end

  # The list sorts by this and every page shows it, so the order always
  # matches the number next to it. With confidence votes > 0 each app starts
  # with that many votes at the catalog average, so a few 5s cannot outrank a
  # long record. Rounded like the displayed value, equal scores fall back to
  # the vote count in the sort.
  def self.community_score_sql(stats)
    confidence = SiteSetting.sideloaded_apps_ranking_confidence_votes
    return "#{stats}.community_avg" if confidence <= 0

    prior = global_average_rating.to_f
    "ROUND((#{confidence} * #{prior} + #{stats}.community_sum)::numeric / " \
      "(#{confidence} + #{stats}.community_count), 1)"
  end

  def self.community_rating_for(topic_id)
    community_stats_for([topic_id])[topic_id.to_i] || { average: 0.0, count: 0 }
  end

  # Mean of every community rating across all apps, the prior for the weighted rank.
  def self.global_average_rating
    DB.query_single(<<~SQL).first
      SELECT SUM(community_sum)::float / NULLIF(SUM(community_count), 0)
      FROM (#{community_stats_sql}) stats
    SQL
  end

  # Returns [topic_id, app_name, previous_category] for every review found.
  # Nothing is written unless apply is true. update_column skips validations
  # on purpose: old reviews may not pass today's rules and that should not
  # block a category move.
  def self.move_to_category(topic_ids, new_category, apply: false)
    if APP_CATEGORIES.exclude?(new_category)
      raise ArgumentError, "unknown app category: #{new_category}"
    end

    where(topic_id: topic_ids)
      .includes(topic: :tags)
      .map do |review|
        previous = review.app_category
        if apply && previous != new_category
          transaction do
            review.update_column(:app_category, new_category)
            topic = review.topic
            topic.custom_fields["apk_app_category"] = new_category
            topic.save_custom_fields
            tags = topic.tags.map(&:name) - ["app-#{previous}"] + ["app-#{new_category}"]
            DiscourseTagging.tag_topic_by_names(
              topic,
              Guardian.new(Discourse.system_user),
              tags.uniq,
            )
          end
        end
        [review.topic_id, review.app_name, previous]
      end
  end

  def self.user_rating_for(topic_id, user_id)
    return nil unless user_id

    standalone = PluginStore.get("sideloaded_ratings", "t#{topic_id}_u#{user_id}")
    return standalone.to_i if standalone.present?

    PostCustomField
      .joins(:post)
      .where(name: "apk_rating")
      .where(posts: { topic_id: topic_id, user_id: user_id, deleted_at: nil })
      .where.not(posts: { post_number: 1 })
      .pick(:value)
      &.to_i
  end

  def self.standalone_ratings_for(topic_id)
    PluginStoreRow
      .where(plugin_name: "sideloaded_ratings")
      .where("key LIKE ?", "t#{topic_id}_u%")
      .pluck(:key, :value)
      .each_with_object({}) { |(key, val), h| h[key] = val.to_i }
      .select { |_, v| v.between?(1, 5) }
  end
end
