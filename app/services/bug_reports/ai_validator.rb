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
          2. Aggressively filter out gibberish, spam, test submissions, and low-quality reports
          3. Categorize valid reports and generate clear, professional titles
          4. Sanitize sensitive information from descriptions

          CRITICAL: These reports will be posted publicly on GitHub. You must be STRICT about filtering.

          REJECT reports if they are:
          - Gibberish (random characters, keyboard mashing like "asdfasdf", "qwerty", "12345", etc.)
          - Test content ("test", "testing", "testing 123", "hello world", etc.)
          - Spam or promotional content (advertisements, links to external sites, marketing copy)
          - Empty or extremely short without meaningful content (less than 20 characters of actual content)
          - Only emojis or special characters without text
          - Not describing a technical issue (complaints, feature requests without bugs, general feedback)
          - Repetitive text (same word/phrase repeated many times)
          - Random strings of characters or numbers
          - Offensive or inappropriate content
          - Copy-pasted content that doesn't relate to a bug
          - Quality score below 50 (low-quality, unclear, or nonsensical reports)

          FLAG FOR CLARIFICATION if:
          - Description is too vague ("it doesn't work", "broken", "fix this")
          - Missing critical information (what page, what action, what happened)
          - Unclear what the expected behavior should be
          - Quality score between 50-70 (needs more detail but potentially valid)

          ACCEPT reports ONLY if they:
          - Clearly describe what went wrong with specific details
          - Include context about what user was trying to do
          - Describe the issue in sufficient detail for investigation
          - Are written in good faith attempt to report a real problem
          - Have a quality score of 70 or higher
          - Contain actual bug description, not just complaints or feature requests

          QUALITY SCORING GUIDELINES:
          - 0-30: Gibberish, spam, or completely invalid
          - 31-49: Very low quality, missing critical information, likely spam
          - 50-69: Needs clarification, vague but potentially valid
          - 70-85: Good quality, clear description with sufficient detail
          - 86-100: Excellent quality, comprehensive description with all relevant details

          IMPORTANT: Respond ONLY with valid JSON. Do not include any markdown formatting or explanatory text.

          Return a JSON object with these fields:
          - valid: boolean (true only if quality_score >= 70 and report is clearly valid)
          - quality_score: number (0-100, be strict - most reports should be 50-70 or lower if invalid)
          - category: string (e.g., "ui", "payment", "performance", "data", "other")
          - severity: string ("low", "medium", "high", "critical")
          - title: string (clear, concise, professional title for the bug - max 80 characters)
          - sanitized_description: string (description with sensitive info redacted - emails, passwords, API keys, personal data)
          - rejection_reason: string (if valid is false, explain why - be specific)
          - needs_clarification: boolean
          - clarification_message: string (if needs_clarification is true, ask specific questions)
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
        quality_score = result[:quality_score] || 0

        # A report is valid if:
        # 1. AI marked it as valid (quality_score >= 70), OR
        # 2. It needs clarification (quality_score 50-69) - still create it but don't auto-create GitHub issue
        # Rejected reports (quality_score < 50) are not valid
        is_valid = valid || needs_clarification

        ValidationResult.new(
          valid: is_valid,
          quality_score: quality_score,
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

      FALLBACK_MIN_DESCRIPTION_LENGTH = 30
      FALLBACK_MIN_QUALITY_SCORE_FOR_VALID = 70

      def fallback_validation_result
        sanitized = sanitize_description(description)

        if sanitized.blank?
          return ValidationResult.new(
            valid: false,
            sanitized_description: "",
            rejection_reason: "Please describe what went wrong so we can investigate."
          )
        end

        # Check for obvious spam/gibberish patterns
        if is_likely_spam?(sanitized)
          return ValidationResult.new(
            valid: false,
            sanitized_description: sanitized,
            rejection_reason: "This appears to be spam or gibberish. Please provide a clear description of the bug."
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

        quality_score = fallback_quality_score_for(sanitized)

        # Only mark as valid if quality score meets threshold
        if quality_score < FALLBACK_MIN_QUALITY_SCORE_FOR_VALID
          return ValidationResult.new(
            valid: false,
            sanitized_description: sanitized,
            needs_clarification: true,
            clarification_message: "Please provide more specific details about the bug, including what you were trying to do and what went wrong.",
            rejection_reason: "Bug report needs more detail to be actionable."
          )
        end

        ValidationResult.new(
          valid: true,
          sanitized_description: sanitized,
          title: fallback_title_for(sanitized),
          category: fallback_category_for(sanitized),
          severity: fallback_severity_for(sanitized),
          quality_score: quality_score,
          needs_clarification: false,
          clarification_message: nil
        )
      end

      def is_likely_spam?(text)
        return true if text.blank?

        # Check for common spam patterns
        spam_patterns = [
          /\b(test|testing|test123|asdf|qwerty|hello world)\b/i,
          /^[^a-z]*$/i, # Only special characters/numbers, no letters
          /(.)\1{8,}/, # Same character repeated 8+ times
          /\b(buy now|click here|free|discount|promo|offer|check out|limited time)\b/i,
          /^.{1,5}$/ # Very short (1-5 characters)
        ]

        spam_patterns.any? { |pattern| text.match?(pattern) }
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

