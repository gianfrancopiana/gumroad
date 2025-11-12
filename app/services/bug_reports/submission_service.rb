# frozen_string_literal: true

module BugReports
  class SubmissionService
    def initialize(params)
      @params = params
    end

    def submit
      validation_result = validate_report

      unless validation_result.valid
        return {
          success: false,
          validation_result: validation_result,
          bug_report: nil
        }
      end

      bug_report = create_bug_report(validation_result)
      process_screenshot(bug_report) if @params[:screenshot].present?
      process_console_logs(bug_report) if @params[:console_logs].present?

      if validation_result.needs_clarification
        bug_report.update(status: "needs_clarification")
      else
        bug_report.update(status: "validated")
        BugReports::CreateGithubIssueJob.perform_async(bug_report.id)
      end

      {
        success: true,
        validation_result: validation_result,
        bug_report: bug_report
      }
    end

    private
      attr_reader :params

      def validate_report
        AiValidator.new(
          description: @params[:description],
          page_url: @params[:page_url],
          technical_context: build_technical_context
        ).validate
      end

      def create_bug_report(validation_result)
        BugReport.create!(
          user: @params[:user],
          page_url: @params[:page_url],
          description: @params[:description],
          sanitized_description: validation_result.sanitized_description,
          title: validation_result.title,
          category: validation_result.category,
          severity: validation_result.severity,
          quality_score: validation_result.quality_score,
          validation_result: validation_result.to_json,
          technical_context: build_technical_context
        )
      end

      def process_screenshot(bug_report)
        screenshot_file = @params[:screenshot]
        return unless screenshot_file.is_a?(ActionDispatch::Http::UploadedFile)

        bug_report.screenshot_original.attach(
          io: screenshot_file.open,
          filename: screenshot_file.original_filename,
          content_type: screenshot_file.content_type
        )

        processor = ScreenshotProcessor.new(bug_report.screenshot_original.blob, page_url: @params[:page_url])
        result = processor.process

        if result && result[:sanitized] && File.exist?(result[:sanitized])
          bug_report.screenshot_sanitized.attach(
            io: File.open(result[:sanitized]),
            filename: "screenshot_sanitized.png",
            content_type: "image/png"
          )
          bug_report.update(blur_metadata: result[:blur_metadata])
        else
          bug_report.screenshot_sanitized.attach(bug_report.screenshot_original.blob)
        end
      rescue => e
        Rails.logger.error("Failed to process screenshot: #{e.message}")
        Bugsnag.notify(e) if defined?(Bugsnag)
      end

      def process_console_logs(bug_report)
        return unless @params[:console_logs]

        bug_report.console_logs.attach(
          io: StringIO.new(@params[:console_logs]),
          filename: "console_logs.txt",
          content_type: "text/plain"
        )
      end

      def build_technical_context
        {
          browser: @params[:browser],
          os: @params[:os],
          user_agent: @params[:user_agent],
          viewport: @params[:viewport],
          timestamp: Time.current.iso8601
        }.compact
      end
  end
end

