# frozen_string_literal: true

request_timeout_in_seconds = 3

# Check if Vercel AI Gateway is configured
vercel_ai_gateway_api_key = GlobalConfig.get("VERCEL_AI_GATEWAY_API_KEY")
vercel_ai_gateway_base_url = GlobalConfig.get("VERCEL_AI_GATEWAY_BASE_URL", "https://ai-gateway.vercel.sh/v1")

if vercel_ai_gateway_api_key.present?
  # Use Vercel AI Gateway
  OpenAI.configure do |config|
    config.access_token = vercel_ai_gateway_api_key
    config.uri_base = vercel_ai_gateway_base_url
    config.request_timeout = request_timeout_in_seconds
  end
else
  # Fall back to OpenAI (backward compatible)
  OpenAI.configure do |config|
    config.access_token = GlobalConfig.get("OPENAI_ACCESS_TOKEN")
    config.request_timeout = request_timeout_in_seconds
  end
end
