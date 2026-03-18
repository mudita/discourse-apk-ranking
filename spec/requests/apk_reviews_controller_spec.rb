# frozen_string_literal: true

require "rails_helper"

describe ApkReviewsController do
  before { SiteSetting.sideloaded_apps_ranking_enabled = true }

  def sideloaded_category
    @sideloaded_category ||=
      Fabricate(
        :category,
        slug: SiteSetting.sideloaded_apps_category_slug,
        name: "Sideloaded Apps Ranking",
      )
  end

  def topic_in_sideloaded
    @topic_in_sideloaded ||= Fabricate(:topic, category: sideloaded_category)
  end

  def apk_review_for_topic(topic)
    Fabricate(
      :apk_review,
      topic: topic,
      user: topic.user,
      app_name: "My App",
      app_category: "utilities",
      apk_link: "https://example.com/app.apk",
      apk_version: "1.2.3",
      author_rating: 5,
      app_description: "A useful app with at least twenty characters.",
    )
  end

  describe "#index" do
    it "returns reviews without login" do
      review = apk_review_for_topic(topic_in_sideloaded)

      get "/sideloaded-apps/reviews.json"

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["reviews"]).to be_present
      expect(parsed["total_count"]).to be >= 1
    end
  end

  describe "#show" do
    it "returns review when it exists" do
      topic = topic_in_sideloaded
      review = apk_review_for_topic(topic)

      get "/sideloaded-apps/reviews/#{topic.id}.json"

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["review"]["app_name"]).to eq("My App")
      expect(parsed["review"]["apk_version"]).to eq("1.2.3")
    end

    it "returns 404 when review does not exist" do
      get "/sideloaded-apps/reviews/999999.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#create" do
    it "requires topic in sideloaded category" do
      sign_in(Fabricate(:user))
      other_topic = Fabricate(:topic)

      post "/sideloaded-apps/reviews.json",
           params: {
             topic_id: other_topic.id,
             review: {
               app_name: "App",
               app_category: "utilities",
               apk_link: "https://example.com/app.apk",
               apk_version: "1.0",
               author_rating: 4,
               app_description: "Description with twenty characters.",
             },
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to include("Sideloaded Apps Ranking category")
    end

    it "allows topic author to create review" do
      user = Fabricate(:user)
      topic = Fabricate(:topic, category: sideloaded_category, user: user)

      sign_in(user)

      post "/sideloaded-apps/reviews.json",
           params: {
             topic_id: topic.id,
             review: {
               app_name: "New App",
               app_category: "social",
               apk_link: "https://example.com/new.apk",
               apk_version: "2.0",
               author_rating: 5,
               app_description: "A new app description with enough characters here.",
             },
           }

      expect(response.status).to eq(201)
      parsed = response.parsed_body
      expect(parsed["review"]["app_name"]).to eq("New App")
      expect(parsed["review"]["apk_version"]).to eq("2.0")
    end

    it "allows staff to create review for others" do
      admin = Fabricate(:admin)
      user = Fabricate(:user)
      topic = Fabricate(:topic, category: sideloaded_category, user: user)

      sign_in(admin)

      post "/sideloaded-apps/reviews.json",
           params: {
             topic_id: topic.id,
             review: {
               app_name: "Staff App",
               app_category: "education",
               apk_link: "https://example.com/staff.apk",
               apk_version: "1.0",
               author_rating: 3,
               app_description: "Staff-created review with sufficient text length.",
             },
           }

      expect(response.status).to eq(201)
      expect(response.parsed_body["review"]["app_name"]).to eq("Staff App")
    end

    it "rejects non-author non-staff" do
      author = Fabricate(:user)
      other_user = Fabricate(:user)
      topic = Fabricate(:topic, category: sideloaded_category, user: author)

      sign_in(other_user)

      post "/sideloaded-apps/reviews.json",
           params: {
             topic_id: topic.id,
             review: {
               app_name: "Hijack",
               app_category: "other",
               apk_link: "https://example.com/hijack.apk",
               apk_version: "1.0",
               author_rating: 1,
               app_description: "Attempt to create review for someone else topic.",
             },
           }

      expect(response.status).to eq(403)
    end
  end

  describe "#report_outdated" do
    it "requires message of at least 20 characters" do
      topic = topic_in_sideloaded
      review = apk_review_for_topic(topic)
      reporter = Fabricate(:user)

      sign_in(reporter)

      post "/sideloaded-apps/report-outdated.json",
           params: { topic_id: topic.id, message: "Short" }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to include("20")
    end

    it "rejects reporting own review" do
      user = Fabricate(:user)
      topic = Fabricate(:topic, category: sideloaded_category, user: user)
      review = apk_review_for_topic(topic)

      sign_in(user)

      post "/sideloaded-apps/report-outdated.json",
           params: { topic_id: topic.id, message: "This is my own outdated report message." }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to include("cannot report your own")
    end

    it "sends report with valid message" do
      author = Fabricate(:user)
      topic = Fabricate(:topic, category: sideloaded_category, user: author)
      review = apk_review_for_topic(topic)
      reporter = Fabricate(:user)

      sign_in(reporter)

      post "/sideloaded-apps/report-outdated.json",
           params: {
             topic_id: topic.id,
             message: "The Play Store shows version 7.0, but this review lists 6.45.",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
    end
  end

  describe "#rate" do
    it "rejects rating own review" do
      user = Fabricate(:user)
      topic = Fabricate(:topic, category: sideloaded_category, user: user)
      apk_review_for_topic(topic)

      sign_in(user)

      post "/sideloaded-apps/rate.json", params: { topic_id: topic.id, rating: 5 }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to include("cannot rate your own")
    end

    it "rejects rating outside 1-5" do
      topic = topic_in_sideloaded
      apk_review_for_topic(topic)
      rater = Fabricate(:user)

      sign_in(rater)

      post "/sideloaded-apps/rate.json", params: { topic_id: topic.id, rating: 6 }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to include("1 and 5")
    end

    it "accepts valid rating" do
      topic = topic_in_sideloaded
      apk_review_for_topic(topic)
      rater = Fabricate(:user)

      sign_in(rater)

      post "/sideloaded-apps/rate.json", params: { topic_id: topic.id, rating: 4 }

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["success"]).to eq(true)
      expect(parsed["user_rating"]).to eq(4)
    end

    it "rejects duplicate rating" do
      topic = topic_in_sideloaded
      apk_review_for_topic(topic)
      rater = Fabricate(:user)

      sign_in(rater)

      post "/sideloaded-apps/rate.json", params: { topic_id: topic.id, rating: 4 }
      expect(response.status).to eq(200)

      post "/sideloaded-apps/rate.json", params: { topic_id: topic.id, rating: 5 }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to include("already rated")
    end
  end

  describe "#track_download" do
    it "updates last_access_date when link is accessible" do
      topic = topic_in_sideloaded
      review = apk_review_for_topic(topic)
      original_date = review.last_access_date

      allow_any_instance_of(ApkReviewsController).to receive(:probe_url) do
        double("response", code: "200")
      end

      sign_in(Fabricate(:user))

      post "/sideloaded-apps/track-download.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(review.reload.last_access_date).to be >= original_date
    end
  end
end
