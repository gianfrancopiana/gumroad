# frozen_string_literal: true

module BugReports
  class GithubIssueService
    include HTTParty

    base_uri "https://api.github.com"

    def initialize
      @token = GlobalConfig.get("GITHUB_ACCESS_TOKEN")
      @repo = GlobalConfig.get("GITHUB_REPO") || "antiwork/gumroad"
    end

    def create_issue(bug_report)
      return nil unless @token.present?

      response = self.class.post(
        "/repos/#{@repo}/issues",
        headers: headers,
        body: issue_body(bug_report).to_json
      )

      if response.success?
        issue_data = response.parsed_response
        {
          number: issue_data["number"],
          url: issue_data["html_url"],
          api_url: issue_data["url"]
        }
      else
        Rails.logger.error("Failed to create GitHub issue: #{response.code} - #{response.body}")
        nil
      end
    rescue => e
      Rails.logger.error("GitHubIssueService error: #{e.message}")
      Bugsnag.notify(e) if defined?(Bugsnag)
      nil
    end

    def update_issue(bug_report)
      return nil unless @token.present? && bug_report.github_issue_number.present?

      response = self.class.patch(
        "/repos/#{@repo}/issues/#{bug_report.github_issue_number}",
        headers: headers,
        body: {
          state: bug_report.resolved? ? "closed" : "open",
          labels: issue_labels(bug_report)
        }.to_json
      )

      response.success?
    rescue => e
      Rails.logger.error("GitHubIssueService update error: #{e.message}")
      Bugsnag.notify(e) if defined?(Bugsnag)
      false
    end

    def add_comment(bug_report, comment)
      return nil unless @token.present? && bug_report.github_issue_number.present?

      response = self.class.post(
        "/repos/#{@repo}/issues/#{bug_report.github_issue_number}/comments",
        headers: headers,
        body: { body: comment }.to_json
      )

      response.success?
    rescue => e
      Rails.logger.error("GitHubIssueService comment error: #{e.message}")
      Bugsnag.notify(e) if defined?(Bugsnag)
      false
    end

    private
      def headers
        {
          "Authorization" => "token #{@token}",
          "Accept" => "application/vnd.github.v3+json",
          "Content-Type" => "application/json"
        }
      end

      def issue_body(bug_report)
        description = bug_report.sanitized_description.presence || bug_report.description

        body_parts = [
          description,
          "",
          "## Technical Details"
        ]

        body_parts << "- **Page URL**: #{bug_report.page_url}"
        body_parts << "- **User Type**: #{bug_report.user_type.capitalize}"
        body_parts << "- **Category**: #{bug_report.category&.capitalize || 'Uncategorized'}"
        body_parts << "- **Severity**: #{bug_report.severity&.capitalize || 'Unknown'}"

        if bug_report.quality_score.present?
          body_parts << "- **Quality Score**: #{bug_report.quality_score}/100"
        end

        if bug_report.technical_context_data.present?
          tech_context = bug_report.technical_context_data

          if tech_context["browser"] || tech_context[:browser]
            browser = tech_context["browser"] || tech_context[:browser]
            browser = browser.length > 100 ? "#{browser[0...100]}..." : browser
            body_parts << "- **Browser**: #{browser}"
          end

          if tech_context["os"] || tech_context[:os]
            body_parts << "- **OS**: #{tech_context["os"] || tech_context[:os]}"
          end

          if tech_context["viewport"] || tech_context[:viewport]
            body_parts << "- **Viewport**: #{tech_context["viewport"] || tech_context[:viewport]}"
          end
        end

        if bug_report.screenshot_sanitized.attached?
          body_parts << "- **Screenshot**: Attached (sanitized for privacy)"
        end

        body_parts << ""
        body_parts << "---"
        body_parts << "*This issue was automatically created from a bug report submitted by a user.*"
        body_parts << "*Internal ID: `#{bug_report.external_id}`*"

        title = bug_report.title.presence || "Bug Report"
        title = title[0...80] if title.length > 80 # GitHub title limit

        { title: title, body: body_parts.join("\n"), labels: issue_labels(bug_report) }
      end

      def issue_labels(bug_report)
        labels = ["bug-report"]
        labels << "user-type:#{bug_report.user_type}" if bug_report.user_type.present?
        labels << "category:#{bug_report.category}" if bug_report.category.present?
        labels << "severity:#{bug_report.severity}" if bug_report.severity.present?
        labels
      end
  end
end

