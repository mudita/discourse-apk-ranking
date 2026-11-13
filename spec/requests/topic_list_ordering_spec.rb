# frozen_string_literal: true

require "rails_helper"

describe "Sideloaded apps topic list ordering" do
  fab!(:category) { Fabricate(:category, slug: "sideloaded-apps-ranking") }
  fab!(:user)

  fab!(:pinned_topic) do
    Fabricate(
      :topic,
      category: category,
      title: "Zzz pinned guide for everyone",
      views: 1,
      posts_count: 1,
      like_count: 0,
      pinned_at: 1.day.ago,
      created_at: 10.days.ago,
    )
  end

  fab!(:popular_topic) do
    Fabricate(
      :topic,
      category: category,
      title: "Popular app review topic",
      views: 500,
      posts_count: 50,
      like_count: 20,
      created_at: 1.day.ago,
    )
  end

  before do
    SiteSetting.sideloaded_apps_ranking_enabled = true
    SiteSetting.sideloaded_apps_category_slug = category.slug
  end

  def topic_ids(params = {})
    get "/c/#{category.slug}/#{category.id}/l/latest.json", params: params
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { |t| t["id"] }
  end

  %w[views posts likes posters created default community_rating].each do |order|
    it "keeps pinned topics on top when sorted by #{order}" do
      expect(topic_ids(order: order).first).to eq(pinned_topic.id)
      expect(topic_ids(order: order, ascending: "true").first).to eq(pinned_topic.id)
    end
  end

  it "ranks by the displayed rounded rating, then by number of ratings" do
    pinned_topic.update!(pinned_at: nil)
    SiteSetting.sideloaded_apps_ranking_confidence_votes = 0
    single_vote = Fabricate(:topic, category: category)
    [single_vote, popular_topic].each { |topic| Fabricate(:apk_review, topic: topic) }
    PluginStore.set("sideloaded_ratings", "t#{single_vote.id}_u#{user.id}", 5)
    # 19 x 5 + 1 x 4 = 4.95, displayed as 5.0
    20.times do |i|
      PluginStore.set("sideloaded_ratings", "t#{popular_topic.id}_u#{1000 + i}", i.zero? ? 4 : 5)
    end

    expect(topic_ids(order: "community_rating").first(2)).to eq([popular_topic.id, single_vote.id])
  end

  it "breaks a weighted tie by the number of votes when the catalog average is near 5" do
    pinned_topic.update!(pinned_at: nil)
    SiteSetting.sideloaded_apps_ranking_confidence_votes = 5
    single_vote = Fabricate(:topic, category: category)
    [single_vote, popular_topic].each { |topic| Fabricate(:apk_review, topic: topic) }
    PluginStore.set("sideloaded_ratings", "t#{single_vote.id}_u#{user.id}", 5)
    20.times do |i|
      PluginStore.set("sideloaded_ratings", "t#{popular_topic.id}_u#{1000 + i}", i.zero? ? 4 : 5)
    end

    expect(topic_ids(order: "community_rating").first(2)).to eq([popular_topic.id, single_vote.id])
  end

  it "orders 5.0(10), 5.0(32), 4.2(19), 4.0(10), 4.2(5) by rating, then by rating count" do
    pinned_topic.update!(pinned_at: nil)
    SiteSetting.sideloaded_apps_ranking_confidence_votes = 0
    rate = ->(topic, ratings) do
      Fabricate(:apk_review, topic: topic)
      ratings.each_with_index do |r, i|
        PluginStore.set("sideloaded_ratings", "t#{topic.id}_u#{2000 + i}", r)
      end
      topic
    end

    five_10 = rate.(Fabricate(:topic, category: category), [5] * 10)
    # 4.97, displayed as 5.0
    five_32 = rate.(Fabricate(:topic, category: category), [5] * 31 + [4])
    # 4.21, displayed as 4.2
    four_two_19 = rate.(Fabricate(:topic, category: category), [5] * 4 + [4] * 15)
    four_10 = rate.(Fabricate(:topic, category: category), [4] * 10)
    four_two_5 = rate.(Fabricate(:topic, category: category), [5, 4, 4, 4, 4])

    expect(topic_ids(order: "community_rating").first(5)).to eq(
      [five_32, five_10, four_two_19, four_two_5, four_10].map(&:id),
    )
  end

  describe "weighted ranking" do
    def rated_app(ratings, first_user_id)
      topic = Fabricate(:topic, category: category)
      Fabricate(:apk_review, topic: topic)
      ratings.each_with_index do |rating, i|
        PluginStore.set("sideloaded_ratings", "t#{topic.id}_u#{first_user_id + i}", rating)
      end
      topic
    end

    fab!(:single_five) { rated_app([5], 3000) }
    # 4.8 over 20 votes
    fab!(:steady_app) { rated_app([5] * 16 + [4] * 4, 3100) }
    # pulls the catalog average down to about 3.9
    fab!(:weak_app) { rated_app([2] * 10, 3200) }

    before { pinned_topic.update!(pinned_at: nil) }

    it "ranks by the plain average when disabled" do
      SiteSetting.sideloaded_apps_ranking_confidence_votes = 0

      expect(topic_ids(order: "community_rating").first(3)).to eq(
        [single_five, steady_app, weak_app].map(&:id),
      )
    end

    it "lets a long consistent record outrank a single vote when enabled" do
      SiteSetting.sideloaded_apps_ranking_confidence_votes = 5

      expect(topic_ids(order: "community_rating").first(3)).to eq(
        [steady_app, single_five, weak_app].map(&:id),
      )
    end

    it "shows the weighted score with the plain average for the tooltip" do
      SiteSetting.sideloaded_apps_ranking_confidence_votes = 5

      get "/c/#{category.slug}/#{category.id}/l/latest.json", params: { order: "community_rating" }
      steady = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == steady_app.id }

      # (5 x 3.90 catalog average + 96) / 25 votes
      expect(steady["apk_community_average"]).to eq(4.6)
      expect(steady["apk_community_plain_average"]).to eq(4.8)
      expect(steady["apk_community_count"]).to eq(20)
    end

    it "never shows a higher rating below a lower one" do
      SiteSetting.sideloaded_apps_ranking_confidence_votes = 5
      # the staging mix where 4.9 (30) landed above 5.0 (12)
      [
        [5] * 47 + [4],
        [5] * 27 + [4] * 3,
        [5] * 12,
        [5] * 7,
        [5] * 7 + [4],
        [5] * 9 + [4] * 2,
      ].each_with_index { |ratings, i| rated_app(ratings, 4000 + i * 100) }

      get "/c/#{category.slug}/#{category.id}/l/latest.json", params: { order: "community_rating" }
      shown =
        response.parsed_body["topic_list"]["topics"].filter_map do |t|
          if t["apk_community_count"].to_i > 0
            [t["apk_community_average"], t["apk_community_count"]]
          end
        end

      expect(shown.size).to eq(9)
      expect(shown).to eq(shown.sort_by { |average, count| [-average, -count] })
    end

    it "shows the same score on the app page" do
      SiteSetting.sideloaded_apps_ranking_confidence_votes = 5

      expect(ApkReview.community_rating_for(steady_app.id)).to include(average: 4.6, count: 20)
    end
  end

  it "ignores ratings stored for topics that are not app reviews" do
    pinned_topic.update!(pinned_at: nil)
    reviewed = Fabricate(:topic, category: category)
    Fabricate(:apk_review, topic: reviewed)
    PluginStore.set("sideloaded_ratings", "t#{reviewed.id}_u#{user.id}", 3)
    PluginStore.set("sideloaded_ratings", "t#{popular_topic.id}_u#{user.id}", 5)

    expect(topic_ids(order: "community_rating").first).to eq(reviewed.id)
    expect(ApkReview.community_rating_for(popular_topic.id)).to include(average: 0.0, count: 0)
  end

  it "does not keep a pin on top once the user has dismissed it" do
    sign_in(user)
    TopicUser.change(user.id, pinned_topic.id, cleared_pinned_at: Time.zone.now)

    expect(topic_ids(order: "views").first).to eq(popular_topic.id)
  end
end
