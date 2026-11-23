# frozen_string_literal: true

require "rails_helper"

describe "Marking apps as available in InkApps" do
  fab!(:category) { Fabricate(:category, slug: "sideloaded-apps-ranking") }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:review) { Fabricate(:apk_review, topic: topic) }
  fab!(:mudita_team) { Fabricate(:group, name: "MuditaTeam") }
  fab!(:admin)
  fab!(:mudita_moderator) { Fabricate(:moderator).tap { |user| mudita_team.add(user) } }
  fab!(:community_moderator, :moderator)
  fab!(:mudita_member) { Fabricate(:user).tap { |user| mudita_team.add(user) } }

  let(:inkapps_url) { "https://inkapps.mudita.com/apps/2530da8b-3b4a-4bbe-bd1c-52f21f4116d3" }

  before do
    SiteSetting.sideloaded_apps_ranking_enabled = true
    SiteSetting.sideloaded_apps_category_slug = category.slug
    SiteSetting.sideloaded_apps_inkapps_editor_groups = mudita_team.id.to_s
  end

  def mark(url)
    put "/sideloaded-apps/reviews/#{topic.id}/inkapps.json", params: { url: url }
  end

  def stored_url
    topic.reload.custom_fields["apk_inkapps_url"]
  end

  it "lets an admin mark an app and logs who did it" do
    sign_in(admin)

    mark(inkapps_url)

    expect(response.status).to eq(200)
    expect(stored_url).to eq(inkapps_url)
    expect(
      UserHistory.where(custom_type: "sideloaded_apps_inkapps", acting_user_id: admin.id),
    ).to exist
  end

  it "lets a moderator from the Mudita group mark an app" do
    sign_in(mudita_moderator)

    mark(inkapps_url)

    expect(response.status).to eq(200)
    expect(stored_url).to eq(inkapps_url)
  end

  it "keeps community moderators and regular members out" do
    [community_moderator, mudita_member].each do |user|
      sign_in(user)
      mark(inkapps_url)

      expect(response.status).to eq(403)
    end
    expect(stored_url).to be_nil
  end

  it "accepts only app pages from inkapps.mudita.com" do
    sign_in(admin)

    mark("https://example.com/apps/2530da8b-3b4a-4bbe-bd1c-52f21f4116d3")

    expect(response.status).to eq(422)
    expect(stored_url).to be_nil
  end

  it "removes the mark when the link is cleared" do
    sign_in(admin)
    mark(inkapps_url)

    mark("")

    expect(response.status).to eq(200)
    expect(stored_url).to be_nil
  end

  it "sends the link with the topic list and tells only editors they can change it" do
    topic.custom_fields["apk_inkapps_url"] = inkapps_url
    topic.save_custom_fields

    get "/c/#{category.slug}/#{category.id}/l/latest.json"
    listed = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == topic.id }
    expect(listed["apk_inkapps_url"]).to eq(inkapps_url)

    sign_in(community_moderator)
    get "/t/#{topic.id}.json"
    expect(response.parsed_body["apk_can_manage_inkapps"]).to eq(false)
    expect(response.parsed_body["apk_review"]["inkapps_url"]).to eq(inkapps_url)

    sign_in(mudita_moderator)
    get "/t/#{topic.id}.json"
    expect(response.parsed_body["apk_can_manage_inkapps"]).to eq(true)
  end
end
