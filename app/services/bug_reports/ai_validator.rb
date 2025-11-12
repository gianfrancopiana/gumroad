# frozen_string_literal: true

module BugReports
  class AiValidator
    VALIDATION_TIMEOUT_IN_SECONDS = 10

    def initialize(description:, page_url: nil, technical_context: {})
      @description = description
      @page_url = page_url
      @technical_context = technical_context || {}
    end

    def validate
      params = {
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
        temperature: 0.3
      }

      params[:response_format] = { type: "json_object" } unless BUG_REPORT_AI_MODEL.start_with?("anthropic/")

      response = openai_client.chat(parameters: params)

      content = response.dig("choices", 0, "message", "content")
      raise "Failed to validate bug report - no content returned" if content.blank?

      payload = extract_json_payload(content)
      result = JSON.parse(payload, symbolize_names: true)
      build_validation_result(result)
    rescue => e
      log_validation_failure(e)
      fallback_validation_result
    end

    private
      attr_reader :description, :page_url, :technical_context

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

          IMPORTANT: Respond ONLY with valid JSON. Do not include any markdown formatting or explanatory text.

          Return a JSON object with these fields:
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

        if technical_context.present?
          prompt += "\n\nTechnical Context:"
          prompt += "\n- Browser: #{technical_context[:browser]}" if technical_context[:browser]
          prompt += "\n- OS: #{technical_context[:os]}" if technical_context[:os]
          prompt += "\n- Viewport: #{technical_context[:viewport]}" if technical_context[:viewport]
        end

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

      def extract_json_payload(content)
        stripped = content.to_s.strip

        fenced_block = stripped.match(/```(?:json)?\s*(\{.*?\})\s*```/m)
        candidate = if fenced_block
          fenced_block[1]
        elsif stripped.start_with?("```")
          stripped.sub(/\A```(?:json)?\s*/i, "").sub(/```$/i, "")
        else
          stripped
        end

        candidate = candidate.strip
        json_start = candidate.index("{")
        json_end = candidate.rindex("}")

        return candidate unless json_start && json_end && json_end > json_start

        candidate[json_start..json_end]
      end

      def log_validation_failure(error)
        details = +"BugReports::AiValidator failed: #{error.class} - #{error.message}"

        if error.respond_to?(:response) && error.response
          status = error.response[:status] rescue nil
          body = error.response[:body] rescue nil
          details << " | status=#{status}" if status
          details << " | body=#{truncate_body(body)}" if body
        end

        Rails.logger.error(details)
      end

      FALLBACK_MIN_DESCRIPTION_LENGTH = 24

      def fallback_validation_result
        sanitized = sanitize_description(description)

        if sanitized.blank?
          return ValidationResult.new(
            valid: false,
            sanitized_description: "",
            rejection_reason: "Please describe what went wrong so we can investigate."
          )
        end

        if sanitized.length < FALLBACK_MIN_DESCRIPTION_LENGTH
          return ValidationResult.new(
            valid: false,
            sanitized_description: sanitized,
            needs_clarification: true,
            clarification_message: "Tell us a bit more about what happened so we can reproduce the issue.",
            rejection_reason: "Bug report description is too short."
          )
        end

        ValidationResult.new(
          valid: true,
          sanitized_description: sanitized,
          title: fallback_title_for(sanitized),
          category: fallback_category_for(sanitized),
          severity: fallback_severity_for(sanitized),
          quality_score: fallback_quality_score_for(sanitized),
          needs_clarification: false,
          clarification_message: nil
        )
      end

      def sanitize_description(text)
        ActionView::Base.full_sanitizer.sanitize(text.to_s).squish
      end

      def fallback_title_for(text)
        text.truncate(80, omission: "…")
      end

      CATEGORY_KEYWORDS = {
        "payment" => /\b(payment|checkout|card|charge|payout|billing)\b/i,
        "performance" => /\b(slow|lag|latency|timeout|performance)\b/i,
        "data" => /\b(data|report|analytics|export|import)\b/i,
        "ui" => /\b(button|layout|ui|screen|modal|design|responsive)\b/i,
        "authentication" => /\b(login|signin|auth|password|2fa)\b/i
      }.freeze

      def fallback_category_for(text)
        CATEGORY_KEYWORDS.each do |category, regex|
          return category if text.match?(regex)
        end
        "other"
      end

      def fallback_severity_for(text)
        return "critical" if text.match?(/\b(crash|cannot\s+login|down|unavailable|security)\b/i)
        return "high" if text.match?(/\b(broken|failure|failed|can't|cannot|blocked)\b/i)
        return "medium" if text.match?(/\b(issue|problem|bug|error)\b/i)
        "low"
      end

      def fallback_quality_score_for(text)
        [[text.length * 2, 100].min, 60].max
      end

      def truncate_body(body)
        return body unless body.respond_to?(:to_s)

        str = body.to_s
        str.length > 300 ? "#{str[0...300]}…" : str
      end
  end
end

