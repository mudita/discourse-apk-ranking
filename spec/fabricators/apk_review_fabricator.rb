# frozen_string_literal: true

Fabricator(:apk_review) do
  topic
  user { |attrs| attrs[:topic]&.user || Fabricate(:user) }
  app_name "Test App"
  app_category "utilities"
  apk_link "https://example.com/app.apk"
  apk_version "1.0.0"
  author_rating 4
  app_description "A test app description with enough characters for validation."
end
