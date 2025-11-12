# frozen_string_literal: true

module BugReports
  class ValidationResult
    attr_reader :valid, :quality_score, :category, :severity, :title, :sanitized_description, :rejection_reason, :needs_clarification, :clarification_message

    def initialize(valid:, quality_score: nil, category: nil, severity: nil, title: nil, sanitized_description: nil, rejection_reason: nil, needs_clarification: false, clarification_message: nil)
      @valid = valid
      @quality_score = quality_score
      @category = category
      @severity = severity
      @title = title
      @sanitized_description = sanitized_description
      @rejection_reason = rejection_reason
      @needs_clarification = needs_clarification
      @clarification_message = clarification_message
    end

    def to_h
      {
        valid: @valid,
        quality_score: @quality_score,
        category: @category,
        severity: @severity,
        title: @title,
        sanitized_description: @sanitized_description,
        rejection_reason: @rejection_reason,
        needs_clarification: @needs_clarification,
        clarification_message: @clarification_message
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end

