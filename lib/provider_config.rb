# frozen_string_literal: true

# Manages provider configuration and availability
class ProviderConfig
  SUPPORTED_PROVIDERS = %i[openai gemini xai].freeze
  PROVIDER_ENV_VARS = {
    openai: 'OPENAI_API_KEY',
    gemini: 'GEMINI_API_KEY',
    xai: 'XAI_API_KEY'
  }.freeze

  def available_providers
    SUPPORTED_PROVIDERS.select { |p| available?(p) }
  end

  def available?(provider)
    env_var = PROVIDER_ENV_VARS[provider]
    return false unless env_var

    key_present?(env_var)
  end

  private

  def key_present?(env_var)
    value = ENV.fetch(env_var, nil)
    value && !value.empty?
  end
end
