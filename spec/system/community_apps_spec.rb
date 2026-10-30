# frozen_string_literal: true

describe "Community Apps", type: :system do
  fab!(:category) { Fabricate(:category, slug: "sideloaded-apps-ranking") }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  before do
    SiteSetting.sideloaded_apps_ranking_enabled = true
    SiteSetting.sideloaded_apps_category_slug = category.slug
  end

  def app_topic(name, app_category: "utilities", ratings: [])
    topic = Fabricate(:topic, category: category, title: "#{name} review by tester")
    Fabricate(:post, topic: topic, user: topic.user)
    Fabricate(:apk_review, topic: topic, app_name: name, app_category: app_category)
    ratings.each_with_index do |rating, i|
      PluginStore.set("sideloaded_ratings", "t#{topic.id}_u#{900_000 + i}", rating)
    end
    topic
  end

  def listed_ids_of(topics)
    ids = topics.map(&:id)
    all("tr.topic-list-item")
      .map { |row| row["data-topic-id"].to_i }
      .select { |id| ids.include?(id) }
  end

  def row(topic)
    "tr.topic-list-item[data-topic-id='#{topic.id}']"
  end

  it "keeps pinned topics first and ranks by the displayed rating, then by count" do
    pinned =
      Fabricate(
        :topic,
        category: category,
        title: "Read this before posting an app",
        pinned_at: 1.day.ago,
      )
    single_vote = app_topic("Single Vote", ratings: [5])
    # 19 x 5 + 1 x 4 averages 4.95, which the list displays as 5.0
    katapult = app_topic("Katapult", ratings: [4] + [5] * 19)
    lower = app_topic("Average App", ratings: [4, 4])

    visit("/c/#{category.slug}/#{category.id}/l/latest?order=community_rating")

    expect(page).to have_css(row(lower))
    expect(listed_ids_of([pinned, single_vote, katapult, lower])).to eq(
      [pinned.id, katapult.id, single_vote.id, lower.id],
    )
    expect(page).to have_css("#{row(katapult)} .sideloaded-community-stars", text: "5.0")
    expect(page).to have_css("#{row(katapult)} .sideloaded-community-count", text: "(20)")
  end

  it "shows no rating for info posts even when a rating was stored for them" do
    faq = Fabricate(:topic, category: category, title: "Frequently asked questions about apps")
    Fabricate(:post, topic: faq, user: faq.user)
    PluginStore.set("sideloaded_ratings", "t#{faq.id}_u#{user.id}", 5)

    visit("/c/#{category.slug}/#{category.id}")

    expect(page).to have_css("#{row(faq)} .sideloaded-no-rating", text: "—")
  end

  it "filters the list with the Tools category pill" do
    flashlight = app_topic("Flashlight", app_category: "tools")
    calculator = app_topic("Calculator", app_category: "utilities")

    visit("/c/#{category.slug}/#{category.id}")
    expect(page).to have_css(row(calculator))

    find(".sideloaded-category-filter__pill", text: "Tools").click

    expect(page).to have_css(row(flashlight))
    expect(page).to have_no_css(row(calculator))
  end

  it "gives every app badge its own column so rows line up" do
    dev_app = app_topic("Dev App", app_category: "tools")
    dev_app.custom_fields["apk_author_is_developer"] = "true"
    dev_app.custom_fields["apk_mmd_dedicated"] = "true"
    dev_app.save_custom_fields
    plain = app_topic("Plain App")

    visit("/c/#{category.slug}/#{category.id}")

    expect(page).to have_css("#{row(dev_app)} td.sideloaded-col--category", text: "Tools")
    columns = all("#{row(dev_app)} td").map { |td| td[:class][/sideloaded-col--\w+|main-link/] }
    expect(columns.compact.first(6)).to eq(
      %w[
        sideloaded-col--category
        sideloaded-col--icon
        main-link
        sideloaded-col--inkapps
        sideloaded-col--mmd
        sideloaded-col--dev
      ],
    )
    expect(page).to have_css("#{row(dev_app)} td.sideloaded-col--mmd .sideloaded-mmd-badge")
    expect(page).to have_css("#{row(dev_app)} td.sideloaded-col--dev .sideloaded-dev-badge")
    expect(page).to have_css("#{row(plain)} td.sideloaded-col--dev")
    expect(page).to have_no_css("#{row(plain)} .sideloaded-dev-badge")
    expect(page).to have_no_css("#{row(plain)} .main-link .sideloaded-app-category-badge")
  end

  it "labels recently updated apps until the label window passes" do
    SiteSetting.sideloaded_apps_updated_badge_days = 14
    fresh = app_topic("Fresh Release")
    stale = app_topic("Old Release")
    ApkReview.find_by(topic_id: fresh.id).update!(version_updated_at: 2.days.ago)
    ApkReview.find_by(topic_id: stale.id).update!(version_updated_at: 30.days.ago)

    visit("/c/#{category.slug}/#{category.id}")

    expect(page).to have_css("#{row(fresh)} .sideloaded-updated-badge", text: "Updated")
    expect(page).to have_css(row(stale))
    expect(page).to have_no_css("#{row(stale)} .sideloaded-updated-badge")
  end

  it "offers Tools in the app submission form" do
    sign_in(user)

    visit("/c/#{category.slug}/#{category.id}")
    find("#create-topic").click

    expect(page).to have_css(
      "#sl-composer-app-category option[value='tools']",
      text: "Tools",
      visible: :all,
    )
  end
end
