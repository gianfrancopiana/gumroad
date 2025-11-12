# frozen_string_literal: true

module BugReports
  class SyncGitHubStatusJob
    include Sidekiq::Job
    sidekiq_options retry: 3, queue: :low

    def perform(bug_report_id)
      bug_report = BugReport.find_by(id: bug_report_id)
      return if bug_report.nil?
      return unless bug_report.github_issue_created?

      service = GitHubIssueService.new
      service.update_issue(bug_report)
    end
  end
end
