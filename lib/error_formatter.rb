# frozen_string_literal: true

# Formats Imago errors for MCP responses
class ErrorFormatter
  ERROR_PREFIXES = {
    'Imago::AuthenticationError' => 'Authentication failed',
    'Imago::RateLimitError' => 'Rate limit exceeded',
    'Imago::InvalidRequestError' => 'Invalid request',
    'Imago::ConfigurationError' => 'Configuration error',
    'Imago::ProviderNotFoundError' => 'Provider not found',
    'Imago::UnsupportedFeatureError' => 'Unsupported feature'
  }.freeze

  def initialize(error)
    @error = error
  end

  def format
    "#{prefix}: #{@error.message}"
  end

  private

  def prefix
    specific_prefix || generic_prefix
  end

  def specific_prefix
    ERROR_PREFIXES[@error.class.to_s]
  end

  def generic_prefix
    return api_error_prefix if api_error?

    'Error'
  end

  def api_error?
    @error.is_a?(Imago::ApiError)
  end

  def api_error_prefix
    "API error (#{@error.status_code})"
  end
end
