# frozen_string_literal: true

module BugReports
  class CreateGithubIssueJob
    include Sidekiq::Job
    sidekiq_options retry: 3, queue: :low

    MIN_QUALITY_SCORE_FOR_GITHUB = 70

    def perform(bug_report_id)
      bug_report = BugReport.find_by(id: bug_report_id)
      return if bug_report.nil?
      return if bug_report.github_issue_created?

      unless meets_quality_threshold?(bug_report)
        Rails.logger.warn("Bug report #{bug_report_id} rejected for GitHub: quality_score=#{bug_report.quality_score} (minimum: #{MIN_QUALITY_SCORE_FOR_GITHUB})")
        bug_report.update!(status: "rejected", rejection_reason: "Quality score too low for public GitHub issue")
        return
      end

      unless still_valid_for_github?(bug_report)
        Rails.logger.warn("Bug report #{bug_report_id} failed re-validation for GitHub")
        bug_report.update!(status: "rejected", rejection_reason: "Failed re-validation check")
        return
      end

      service = GithubIssueService.new
      issue_data = service.create_issue(bug_report)

      if issue_data
        bug_report.update!(
          github_issue_number: issue_data[:number].to_s,
          github_issue_url: issue_data[:url],
          status: "github_created"
        )

        BugReports::SendConfirmationEmailJob.perform_async(bug_report_id)
      else
        Rails.logger.error("Failed to create GitHub issue for bug report #{bug_report_id}")
      end
    end

    private
      def meets_quality_threshold?(bug_report)
        return false if bug_report.quality_score.nil?
        bug_report.quality_score >= MIN_QUALITY_SCORE_FOR_GITHUB
      end

      def still_valid_for_github?(bug_report)
        # Check for common spam patterns
        description = bug_report.sanitized_description || bug_report.description
        return false if description.blank?
        return false if description.length < 20

        # Check for obvious spam patterns
        spam_patterns = [
          /\b(test|testing|test123|asdf|qwerty)\b/i,
          /^[^a-z]*$/i, # Only special characters/numbers
          /(.)\1{10,}/, # Repeated characters
          /\b(buy now|click here|free|discount|promo|offer)\b/i # Spam keywords
        ]

        spam_patterns.none? { |pattern| description.match?(pattern) }
      end
  end
end

