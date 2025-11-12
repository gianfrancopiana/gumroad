# frozen_string_literal: true

module BugReports
  class AiValidator
    VALIDATION_TIMEOUT_IN_SECONDS = 10

    def initialize(description:, page_url: nil)
      @description = description
      @page_url = page_url
    end

    def validate
      response = openai_client.chat(
        parameters: {
          model: BUG_REPORT_AI_MODEL,
          messages: [
            {
              role: "system",
              content: system_prompt
            },
            {
              role: "user",
              content: user_prompt
            }
          ],
          response_format: { type: "json_object" },
          temperature: 0.3
        }
      )

      content = response.dig("choices", 0, "message", "content")
      raise "Failed to validate bug report - no content returned" if content.blank?

      result = JSON.parse(content, symbolize_names: true)
      build_validation_result(result)
    rescue => e
      Rails.logger.error("BugReports::AiValidator failed: #{e.message}")
      ValidationResult.new(
        valid: false,
        rejection_reason: "Validation service temporarily unavailable. Please try again."
      )
    end

    private
      attr_reader :description, :page_url

      def openai_client
        OpenAI::Client.new(request_timeout: VALIDATION_TIMEOUT_IN_SECONDS)
      end

      def system_prompt
        <<~PROMPT
          You are a bug report validator for Gumroad, an e-commerce platform. Your job is to:
          1. Determine if a bug report is valid and meaningful
          2. Filter out gibberish, spam, test submissions, and low-quality reports
          3. Categorize valid reports and generate clear titles
          4. Sanitize sensitive information from descriptions

          Reject reports if they are:
          - Gibberish (random characters, keyboard mashing like "asdfasdf")
          - Test content ("test", "testing 123", etc.)
          - Spam or promotional content
          - Empty or extremely short without meaningful content
          - Only emojis or special characters
          - Not describing a technical issue

          Flag for clarification if:
          - Description is too vague ("it doesn't work")
          - Missing critical information (what page, what action, what happened)
          - Unclear what the expected behavior should be

          Accept reports if they:
          - Clearly describe what went wrong
          - Include context about what user was trying to do
          - Describe the issue in sufficient detail for investigation
          - Are written in good faith attempt to report a real problem

          Return JSON with:
          - valid: boolean
          - quality_score: number (0-100)
          - category: string (e.g., "ui", "payment", "performance", "data", "other")
          - severity: string ("low", "medium", "high", "critical")
          - title: string (clear, concise title for the bug)
          - sanitized_description: string (description with sensitive info redacted)
          - rejection_reason: string (if valid is false)
          - needs_clarification: boolean
          - clarification_message: string (if needs_clarification is true)
        PROMPT
      end

      def user_prompt
        prompt = "Bug report description: #{description}"
        prompt += "\nPage URL: #{page_url}" if page_url.present?
        prompt
      end

      def build_validation_result(result)
        valid = result[:valid] == true
        needs_clarification = result[:needs_clarification] == true

        ValidationResult.new(
          valid: valid && !needs_clarification,
          quality_score: result[:quality_score],
          category: result[:category],
          severity: result[:severity],
          title: result[:title],
          sanitized_description: result[:sanitized_description] || description,
          rejection_reason: result[:rejection_reason],
          needs_clarification: needs_clarification,
          clarification_message: result[:clarification_message]
        )
      end
  end
end

