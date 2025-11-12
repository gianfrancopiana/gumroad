# frozen_string_literal: true

class BugReportMailer < ApplicationMailer
  layout "layouts/email"

  def confirmation(bug_report)
    @bug_report = bug_report
    @user = bug_report.user

    return unless @user&.form_email.present?

    mail(
      to: @user.form_email,
      subject: "Bug Report Submitted - #{bug_report.title || 'Bug Report'}",
      delivery_method_options: MailerInfo.random_delivery_method_options(domain: :gumroad)
    )
  end

  def status_update(bug_report)
    @bug_report = bug_report
    @user = bug_report.user

    return unless @user&.form_email.present?

    mail(
      to: @user.form_email,
      subject: "Bug Report Update - #{bug_report.title || 'Bug Report'}",
      delivery_method_options: MailerInfo.random_delivery_method_options(domain: :gumroad)
    )
  end
end

