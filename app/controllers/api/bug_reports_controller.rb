# frozen_string_literal: true

class Api::BugReportsController < ApplicationController
  include Throttling

  skip_before_action :verify_authenticity_token
  before_action :throttle_submission

  def create
    service = BugReports::SubmissionService.new(submission_params)
    result = service.submit

    if result[:success]
      render json: {
        success: true,
        bug_report: {
          id: result[:bug_report].external_id,
          status: result[:bug_report].status,
          needs_clarification: result[:bug_report].needs_clarification?,
          clarification_message: result[:validation_result].clarification_message
        }
      }, status: :created
    else
      render json: {
        success: false,
        error: result[:validation_result].rejection_reason || "Invalid bug report",
        needs_clarification: result[:validation_result].needs_clarification,
        clarification_message: result[:validation_result].clarification_message
      }, status: :unprocessable_entity
    end
  end

  private
    def submission_params
      {
        description: params[:description],
        page_url: params[:page_url] || request.referer || "unknown",
        browser: params[:browser],
        os: params[:os],
        user_agent: params[:user_agent],
        viewport: params[:viewport],
        console_logs: params[:console_logs],
        screenshot: params[:screenshot],
        user: current_user
      }.compact
    end

    def throttle_submission
      throttle_key = "bug_report_submission:#{request.remote_ip}"
      limit = Rails.env.production? ? 10 : 100
      throttle!(key: throttle_key, limit: limit, period: 1.hour)
    end
end

