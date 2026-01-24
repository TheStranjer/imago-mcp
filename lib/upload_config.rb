# frozen_string_literal: true

# Configuration for image uploads
class UploadConfig
  DEFAULT_USER_AGENT = 'imago-mcp/1.0.0'

  def enabled?
    url && !url.empty?
  end

  def url
    ENV.fetch('UPLOAD_URL', nil)
  end

  def expiration
    ENV.fetch('UPLOAD_EXPIRATION', '1').to_i
  end

  def user_agent
    ENV.fetch('UPLOAD_USER_AGENT', DEFAULT_USER_AGENT)
  end
end
