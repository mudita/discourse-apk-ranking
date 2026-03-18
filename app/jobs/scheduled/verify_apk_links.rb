# frozen_string_literal: true

require "digest"

module ::Jobs
  class VerifyApkLinks < ::Jobs::Scheduled
    every 5.minutes

    LINK_CHECK_UA = "Mozilla/5.0 (compatible; DiscourseBot/1.0; +https://discourse.org)"

    def execute(args)
      return unless SiteSetting.sideloaded_apps_ranking_enabled
      return unless SiteSetting.sideloaded_apps_verification_enabled

      interval = SiteSetting.sideloaded_apps_verification_interval_minutes.minutes
      max_size = SiteSetting.sideloaded_apps_max_apk_file_size_mb.megabytes

      ApkReview.where.not(apk_link: [nil, ""]).find_each do |review|
        verification = ApkVerification.find_by(topic_id: review.topic_id)
        next if verification&.last_checked_at && verification.last_checked_at > interval.ago

        verify_single_link(review, max_size)
      rescue => e
        Rails.logger.error("[Sideloaded Apps] Error verifying #{review.apk_link}: #{e.message}")
      end
    end

    private

    def verify_single_link(review, max_size)
      verification = ApkVerification.find_or_initialize_by(topic_id: review.topic_id)

      availability = check_availability(review.apk_link)
      verification.availability_status = availability[:status]
      verification.availability_description = availability[:description]
      verification.last_http_status = availability[:http_status]
      verification.link_type = availability[:link_type] if availability[:link_type].present?

      if availability[:status] == "available"
        review.update_column(:last_access_date, Time.current)
      end

      if availability[:status] == "available" && review.apk_checksum.present?
        consistency = check_consistency(review.apk_link, review.apk_checksum, max_size)
        verification.consistency_status = consistency[:status]
        verification.consistency_description = consistency[:description]
        verification.last_computed_checksum = consistency[:checksum]
      elsif review.apk_checksum.blank?
        verification.consistency_status = "unknown"
        verification.consistency_description = "No checksum available"
      else
        verification.consistency_status = "unknown"
        verification.consistency_description = "Cannot verify — file is unavailable"
      end

      verification.last_checked_at = Time.current
      verification.save!
    end

    def probe_url(uri, open_timeout: 10, read_timeout: 10)
      FinalDestination::HTTP.start(
        uri.host, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: open_timeout,
        read_timeout: read_timeout,
      ) do |http|
        head = Net::HTTP::Head.new(uri.request_uri)
        head["User-Agent"] = LINK_CHECK_UA
        head["Accept"] = "*/*"
        response = http.request(head)

        if response.code.to_i.in?([403, 405, 501])
          get = Net::HTTP::Get.new(uri.request_uri)
          get["User-Agent"] = LINK_CHECK_UA
          get["Accept"] = "*/*"
          get["Range"] = "bytes=0-0"
          response = http.request(get)
        end

        response
      end
    end

    def check_availability(url)
      uri = URI.parse(url)
      response = probe_url(uri)

      code = response.code.to_i
      content_type = response["content-type"].to_s.downcase
      is_html = content_type.include?("text/html")
      is_download = response["content-disposition"].to_s.downcase.include?("attachment") ||
        content_type.include?("application/") ||
        content_type.include?("binary") ||
        url.match?(/\.apk\z/i)
      link_type = (is_html && !is_download) ? "webpage" : "file"

      if code.between?(200, 399)
        { status: "available", description: "Link is accessible (HTTP #{code})", http_status: code, link_type: link_type }
      else
        { status: "unavailable", description: "Link returned HTTP #{code}", http_status: code, link_type: link_type }
      end
    rescue => e
      { status: "unavailable", description: "Connection error: #{e.message}", http_status: nil, link_type: nil }
    end

    def check_consistency(url, original_checksum, max_size)
      uri = URI.parse(url)
      sha256 = Digest::SHA256.new

      FinalDestination::HTTP.start(
        uri.host, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 10,
        read_timeout: 60,
      ) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = LINK_CHECK_UA
        request["Accept"] = "*/*"
        total_bytes = 0

        http.request(request) do |response|
          unless response.code.to_i.between?(200, 299)
            return { status: "inconsistent", description: "Could not download file (HTTP #{response.code})", checksum: nil }
          end

          response.read_body do |chunk|
            total_bytes += chunk.bytesize
            if total_bytes > max_size
              return { status: "inconsistent", description: "File exceeds maximum size limit", checksum: nil }
            end
            sha256.update(chunk)
          end
        end
      end

      computed = sha256.hexdigest

      if computed == original_checksum
        { status: "consistent", description: "Checksum matches (SHA-256: #{computed[0..11]}...)", checksum: computed }
      else
        { status: "inconsistent", description: "Checksum mismatch — file may have been modified since submission", checksum: computed }
      end
    rescue => e
      { status: "inconsistent", description: "Verification error: #{e.message}", checksum: nil }
    end
  end
end
