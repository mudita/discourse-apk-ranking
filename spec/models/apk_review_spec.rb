# frozen_string_literal: true

require "rails_helper"

describe ApkReview do
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
