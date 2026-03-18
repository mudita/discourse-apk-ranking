# frozen_string_literal: true

# Phase 2: Stores results of automatic APK link verification
class ::ApkVerification < ActiveRecord::Base
  self.table_name = "apk_verifications"

  belongs_to :topic, class_name: "::Topic"
  has_one :review, class_name: "::ApkReview", foreign_key: :topic_id, primary_key: :topic_id

  # ── Status Constants ─────────────────────────────────────
  AVAILABILITY_STATUSES = %w[available unavailable unknown].freeze
  CONSISTENCY_STATUSES  = %w[consistent inconsistent unknown].freeze

  validates :topic_id, presence: true, uniqueness: true
  validates :availability_status, inclusion: { in: AVAILABILITY_STATUSES }
  validates :consistency_status,  inclusion: { in: CONSISTENCY_STATUSES }

  # ── Instance Methods ─────────────────────────────────────
  def available?
    availability_status == "available"
  end

  def consistent?
    consistency_status == "consistent"
  end

  def stale?(minutes = nil)
    interval = minutes || SiteSetting.sideloaded_apps_verification_interval_minutes
    last_checked_at.nil? || last_checked_at < interval.minutes.ago
  end
end
