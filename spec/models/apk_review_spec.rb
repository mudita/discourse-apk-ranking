# frozen_string_literal: true

require "rails_helper"

describe ApkReview do
  describe ".author_rating_from" do
    it "gives developers no rating" do
      fields = { "apk_author_is_developer" => "true", "apk_author_rating" => "5" }
      expect(ApkReview.author_rating_from(fields)).to be_nil
    end

    it "clamps the rating of other reviewers and defaults a missing one to 3" do
      expect(ApkReview.author_rating_from("apk_author_rating" => "9")).to eq(5)
      expect(ApkReview.author_rating_from("apk_author_rating" => "")).to eq(3)
      expect(ApkReview.author_rating_from("apk_author_is_developer" => "false")).to eq(3)
    end
  end

  describe "author rating validation" do
    fab!(:topic)

    it "requires a rating from a reviewer who is not the developer" do
      review = Fabricate.build(:apk_review, topic: topic, author_rating: nil)

      expect(review).not_to be_valid
      expect(review.errors[:author_rating]).to be_present
    end

    it "rejects a rating on a developer's review" do
      topic.custom_fields["apk_author_is_developer"] = "true"
      topic.save_custom_fields

      expect(Fabricate.build(:apk_review, topic: topic, author_rating: 4)).not_to be_valid
      expect(Fabricate.build(:apk_review, topic: topic, author_rating: nil)).to be_valid
    end
  end

  describe ".move_to_category" do
    fab!(:category) { Fabricate(:category, slug: "sideloaded-apps-ranking") }
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:review) { Fabricate(:apk_review, topic: topic, app_category: "utilities") }

    before do
      SiteSetting.tagging_enabled = true
      DiscourseTagging.tag_topic_by_names(
        topic,
        Guardian.new(Discourse.system_user),
        %w[app-utilities kompakt],
      )
    end

    it "only reports what would change on a dry run" do
      result = ApkReview.move_to_category([topic.id], "tools")

      expect(result).to eq([[topic.id, review.app_name, "utilities"]])
      expect(review.reload.app_category).to eq("utilities")
      expect(topic.reload.tags.map(&:name)).to contain_exactly("app-utilities", "kompakt")
    end

    it "moves the review, its custom field and its category tag when applied" do
      ApkReview.move_to_category([topic.id], "tools", apply: true)

      expect(review.reload.app_category).to eq("tools")
      expect(topic.reload.custom_fields["apk_app_category"]).to eq("tools")
      expect(topic.tags.map(&:name)).to contain_exactly("app-tools", "kompakt")
    end

    it "rejects categories the plugin does not know" do
      expect { ApkReview.move_to_category([topic.id], "toolz", apply: true) }.to raise_error(
        ArgumentError,
      )
      expect(review.reload.app_category).to eq("utilities")
    end
  end
end
