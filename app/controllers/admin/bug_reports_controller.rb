# frozen_string_literal: true

class Admin::BugReportsController < Admin::BaseController
  include Pagy::Backend

  def index
    @title = "Bug reports"
    @pagy, @bug_reports = pagy(bug_reports_scope, items: 50)

    render inertia: "Admin/BugReports/Index", props: {
      bug_reports: @bug_reports.map { |br| bug_report_props(br) },
      pagination: PagyPresenter.new(@pagy).props,
      filters: {
        status: params[:status],
        category: params[:category],
        user_type: params[:user_type]
      }
    }
  end

  def show
    @bug_report = BugReport.find_by_external_id(params[:id])

    unless @bug_report
      flash[:alert] = "Bug report not found"
      redirect_to admin_bug_reports_path
      return
    end

    @title = @bug_report.title || "Bug report"

    render inertia: "Admin/BugReports/Show", props: {
      bug_report: bug_report_detail_props(@bug_report)
    }
  end

  def update
    @bug_report = BugReport.find_by_external_id(params[:id])

    unless @bug_report
      return render json: { success: false, error: "Bug report not found" }, status: :not_found
    end

    if @bug_report.update(bug_report_params)
      if @bug_report.status_changed?
        BugReports::SyncGitHubStatusJob.perform_async(@bug_report.id) if @bug_report.github_issue_created?
        BugReports::SendStatusUpdateEmailJob.perform_async(@bug_report.id) if @bug_report.user.present?
      end

      render json: {
        success: true,
        bug_report: bug_report_detail_props(@bug_report)
      }
    else
      render json: {
        success: false,
        errors: @bug_report.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private
    def bug_reports_scope
      scope = BugReport.all.order(created_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(category: params[:category]) if params[:category].present?
      scope
    end

    def bug_report_props(bug_report)
      {
        id: bug_report.external_id,
        title: bug_report.title,
        description: bug_report.description,
        sanitized_description: bug_report.sanitized_description,
        status: bug_report.status,
        category: bug_report.category,
        severity: bug_report.severity,
        quality_score: bug_report.quality_score,
        user_type: bug_report.user_type,
        page_url: bug_report.page_url,
        github_issue_url: bug_report.github_issue_url,
        github_issue_number: bug_report.github_issue_number,
        created_at: bug_report.created_at.iso8601,
        user: bug_report.user ? {
          id: bug_report.user.external_id,
          email: bug_report.user.email,
          name: bug_report.user.name
        } : nil
      }
    end

    def bug_report_detail_props(bug_report)
      bug_report_props(bug_report).merge(
        validation_result: bug_report.validation_result_data,
        technical_context: bug_report.technical_context_data,
        blur_metadata: bug_report.blur_metadata_data,
        internal_notes: bug_report.internal_notes,
        screenshot_original_url: bug_report.screenshot_original.attached? ? url_for(bug_report.screenshot_original) : nil,
        screenshot_sanitized_url: bug_report.screenshot_sanitized.attached? ? url_for(bug_report.screenshot_sanitized) : nil,
        console_logs_url: bug_report.console_logs.attached? ? url_for(bug_report.console_logs) : nil
      )
    end

    def bug_report_params
      params.require(:bug_report).permit(:status, :category, :severity, :internal_notes)
    end
end

