# frozen_string_literal: true

desc "Print every Community App as CSV: topic_id, app name, category, author, url"
task "apk_ranking:list_apps" => :environment do
  require "csv"

  puts CSV.generate_line(%w[topic_id app_name app_category author url])
  ApkReview
    .includes(:user, :topic)
    .order(:app_category, :app_name)
    .each do |review|
      puts CSV.generate_line(
             [
               review.topic_id,
               review.app_name,
               review.app_category,
               review.user&.username,
               review.topic && "#{Discourse.base_url}#{review.topic.relative_url}",
             ],
           )
    end
end

desc "Move Community Apps to another app category: TOPIC_IDS=1,2,3 CATEGORY=tools [APPLY=1]"
task "apk_ranking:move_category" => :environment do
  ids = ENV.fetch("TOPIC_IDS", "").split(",").map(&:to_i).reject(&:zero?)
  category = ENV.fetch("CATEGORY", "")
  apply = ENV["APPLY"] == "1"

  if ids.empty? || category.blank?
    abort "Usage: TOPIC_IDS=1,2,3 CATEGORY=tools [APPLY=1] rake apk_ranking:move_category"
  end

  begin
    moved = ApkReview.move_to_category(ids, category, apply: apply)
  rescue ArgumentError => e
    abort "#{e.message}. Known categories: #{ApkReview::APP_CATEGORIES.join(", ")}"
  end

  moved.each do |topic_id, name, previous|
    if previous == category
      puts "already in #{category}: ##{topic_id} #{name}"
    else
      puts "#{apply ? "moved" : "would move"} ##{topic_id} #{name}: #{previous} -> #{category}"
    end
  end

  missing = ids - moved.map(&:first)
  puts "no app review for topic ids: #{missing.join(", ")}" if missing.any?
  puts "Dry run, nothing changed. Run again with APPLY=1 to apply." unless apply
end
