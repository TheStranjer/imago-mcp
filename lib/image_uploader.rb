# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'base64'
require_relative 'multipart_builder'
require_relative 'upload_config'

# Uploads images to a file hosting service
class ImageUploader
  MIME_TYPE_EXTENSIONS = {
    'image/png' => 'png',
    'image/jpeg' => 'jpg',
    'image/jpg' => 'jpg',
    'image/gif' => 'gif',
    'image/webp' => 'webp'
  }.freeze

  def initialize(config: UploadConfig.new)
    @config = config
  end

  def upload(base64_data, mime_type)
    perform_full_upload(base64_data, mime_type)
  end

  private

  def perform_full_upload(base64_data, mime_type)
    binary = decode_base64(base64_data)
    extension = mime_extension(mime_type)
    perform_upload(binary, extension)
  end

  def decode_base64(data)
    Base64.decode64(data)
  end

  def mime_extension(mime_type)
    MIME_TYPE_EXTENSIONS.fetch(mime_type, 'png')
  end

  def perform_upload(binary, extension)
    builder = MultipartBuilder.new
    body = build_body(builder, binary, extension)
    send_request(builder, body)
  end

  def build_body(builder, binary, extension)
    builder.build(binary, extension, @config.expiration)
  end

  def send_request(builder, body)
    uri = parse_uri
    request = create_request(uri, builder, body)
    execute_and_process(uri, request)
  end

  def parse_uri
    URI.parse(@config.url)
  end

  def create_request(uri, builder, body)
    request = Net::HTTP::Post.new(uri.request_uri)
    set_headers(request, builder)
    request.body = body
    request
  end

  def set_headers(request, builder)
    request['Content-Type'] = builder.content_type
    request['User-Agent'] = @config.user_agent
  end

  def execute_and_process(uri, request)
    response = execute_request(uri, request)
    build_result(response)
  end

  def execute_request(uri, request)
    use_ssl = uri.scheme == 'https'
    http_request(uri, use_ssl, request)
  end

  def http_request(uri, use_ssl, request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl) do |http|
      http.request(request)
    end
  end

  def build_result(response)
    return response.body.strip if success_response?(response)

    failure_result(response)
  end

  def failure_result(response)
    { error: true, status_code: response.code, body: response.body.strip }
  end

  def success_response?(response)
    response.code.start_with?('2')
  end
end
