# frozen_string_literal: true

class BugReport < ApplicationRecord
  include ExternalId
  include Deletable

  belongs_to :user, optional: true

  has_one_attached :screenshot_original
  has_one_attached :screenshot_sanitized
  has_one_attached :console_logs

  validates :page_url, presence: true
  validates :description, presence: true
  validates :status, presence: true

  enum status: {
    pending: "pending",
    validated: "validated",
    rejected: "rejected",
    needs_clarification: "needs_clarification",
    github_created: "github_created",
    resolved: "resolved",
    duplicate: "duplicate"
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :validated_reports, -> { where(status: [:validated, :github_created, :resolved]) }
  scope :rejected_reports, -> { where(status: :rejected) }

  def user_type
    return "anonymous" unless user
    user.has_any_sales? ? "seller" : "buyer"
  end

  def validation_result_data
    return nil if validation_result.blank?
    JSON.parse(validation_result)
  rescue JSON::ParserError
    nil
  end

  def technical_context_data
    return {} if technical_context.blank?
    technical_context.is_a?(Hash) ? technical_context : JSON.parse(technical_context)
  rescue JSON::ParserError
    {}
  end

  def blur_metadata_data
    return {} if blur_metadata.blank?
    blur_metadata.is_a?(Hash) ? blur_metadata : JSON.parse(blur_metadata)
  rescue JSON::ParserError
    {}
  end

  def github_issue_created?
    github_issue_number.present?
  end

  def rejected?
    status == "rejected"
  end

  def needs_clarification?
    status == "needs_clarification"
  end
end

