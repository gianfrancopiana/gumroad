# frozen_string_literal: true

module BugReports
  class SendConfirmationEmailJob
    include Sidekiq::Job
    sidekiq_options retry: 3, queue: :low

    def perform(bug_report_id)
      bug_report = BugReport.find_by(id: bug_report_id)
      return if bug_report.nil?

      email = bug_report.user&.form_email
      return if email.blank?

      BugReportMailer.confirmation(bug_report).deliver_now
    end
  end
end

