# frozen_string_literal: true

BUG_REPORT_SANITIZATION_CONFIG = YAML.load_file(Rails.root.join("config", "bug_report_sanitization.yml")).deep_symbolize_keys.freeze
