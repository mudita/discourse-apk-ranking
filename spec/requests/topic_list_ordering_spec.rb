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
    single_vote = Fabricate(:topic, category: category)
    PluginStore.set("sideloaded_ratings", "t#{single_vote.id}_u#{user.id}", 5)
    # 19 x 5 + 1 x 4 = 4.95, displayed as 5.0
    20.times do |i|
      PluginStore.set("sideloaded_ratings", "t#{popular_topic.id}_u#{1000 + i}", i.zero? ? 4 : 5)
    end

    expect(topic_ids(order: "community_rating").first(2)).to eq([popular_topic.id, single_vote.id])
  end

  it "orders 5.0(10), 5.0(32), 4.2(19), 4.0(10), 4.2(5) by rating, then by rating count" do
    pinned_topic.update!(pinned_at: nil)
    rate = ->(topic, ratings) do
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

  it "does not keep a pin on top once the user has dismissed it" do
    sign_in(user)
    TopicUser.change(user.id, pinned_topic.id, cleared_pinned_at: Time.zone.now)

    expect(topic_ids(order: "views").first).to eq(popular_topic.id)
  end
end
