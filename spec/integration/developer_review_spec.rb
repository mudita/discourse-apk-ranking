# frozen_string_literal: true

require "rails_helper"

describe "Reviews posted by the app developer" do
  fab!(:category) { Fabricate(:category, slug: "sideloaded-apps-ranking") }
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }

  before do
    SiteSetting.sideloaded_apps_ranking_enabled = true
    SiteSetting.sideloaded_apps_category_slug = category.slug
    stub_request(:any, "https://example.com/notes.apk")
  end

  def submit_review(developer:, rating: "4")
    PostCreator.create!(
      author,
      title: "Pocket Notes review by #{author.username}",
      raw: "Notes app that works well on the Kompakt screen.",
      category: category.id,
      skip_validations: true,
      custom_fields: {
        "apk_app_name" => "Pocket Notes",
        "apk_app_category" => "productivity",
        "apk_link" => "https://example.com/notes.apk",
        "apk_version" => "1.0.0",
        "apk_description" => "Simple notes app with offline sync and export.",
        "apk_author_rating" => rating,
        "apk_author_is_developer" => developer.to_s,
      },
    ).topic
  end

  it "stores no author rating when the developer submits the app" do
    topic = submit_review(developer: true, rating: "")

    expect(ApkReview.find_by(topic_id: topic.id).author_rating).to be_nil
  end

  it "ignores a rating sent by the developer anyway" do
    topic = submit_review(developer: true, rating: "5")

    expect(ApkReview.find_by(topic_id: topic.id).author_rating).to be_nil
  end

  it "keeps the rating of a reviewer who is not the developer" do
    topic = submit_review(developer: false, rating: "4")

    expect(ApkReview.find_by(topic_id: topic.id).author_rating).to eq(4)
  end

  it "does not let the developer add a rating when editing the review" do
    topic = submit_review(developer: true, rating: "")
    sign_in(author)

    put "/sideloaded-apps/reviews/#{topic.id}.json",
        params: {
          review: {
            author_rating: 5,
            app_description: "Simple notes app with offline sync, export and tags.",
          },
        }

    expect(response.status).to eq(200)
    review = ApkReview.find_by(topic_id: topic.id)
    expect(review.author_rating).to be_nil
    expect(review.app_description).to include("tags")
  end

  it "leaves the author rating line out of the developer's replies" do
    topic = submit_review(developer: true, rating: "")

    reply =
      PostCreator.create!(
        author,
        topic_id: topic.id,
        raw: "Version 1.0.1 fixes the sync issue.",
        skip_validations: true,
      )

    expect(reply.reload.raw).to include("Version 1.0.1 fixes the sync issue.")
    expect(reply.raw).not_to include(I18n.t("js.sideloaded_apps.reply_author_rating_prefix"))
  end

  it "keeps the author rating line in replies of a reviewer who is not the developer" do
    topic = submit_review(developer: false, rating: "4")

    reply =
      PostCreator.create!(
        author,
        topic_id: topic.id,
        raw: "Still works after the update.",
        skip_validations: true,
      )

    expect(reply.reload.raw).to include(I18n.t("js.sideloaded_apps.reply_author_rating_prefix"))
  end
end
