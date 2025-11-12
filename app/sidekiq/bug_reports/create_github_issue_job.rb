# frozen_string_literal: true

module BugReports
  class CreateGithubIssueJob
    include Sidekiq::Job
    sidekiq_options retry: 3, queue: :low

    def perform(bug_report_id)
      bug_report = BugReport.find_by(id: bug_report_id)
      return if bug_report.nil?
      return if bug_report.github_issue_created?

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
  end
end

