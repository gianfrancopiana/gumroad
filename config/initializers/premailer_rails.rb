# frozen_string_literal: true

unless Rails.env.development?
  Premailer::Rails.config[:remove_ids] = false
  Premailer::Rails.config[:preserve_style_attribute] = true
end

if Rails.env.development?
  Rails.application.config.after_initialize do
    Mail.unregister_interceptor(Premailer::Rails::Hook)
  end
end
