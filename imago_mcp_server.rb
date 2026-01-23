#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'imago'
require 'net/http'
require 'uri'
require 'base64'
require 'securerandom'

# MCP Server for the Imago gem - provides image generation through multiple AI providers
class ImagoMcpServer
  SUPPORTED_PROVIDERS = %i[openai gemini xai].freeze
  PROVIDER_ENV_VARS = {
    openai: 'OPENAI_API_KEY',
    gemini: 'GEMINI_API_KEY',
    xai: 'XAI_API_KEY'
  }.freeze
  MIME_TYPE_EXTENSIONS = {
    'image/png' => 'png',
    'image/jpeg' => 'jpg',
    'image/jpg' => 'jpg',
    'image/gif' => 'gif',
    'image/webp' => 'webp'
  }.freeze
  DEFAULT_USER_AGENT = 'curl/8.5.0'

  def initialize(input: $stdin, output: $stdout)
    @input = input
    @output = output
    @running = false
    debug_log("Server initialized. UPLOAD_URL: #{upload_url.inspect}, " \
              "UPLOAD_EXPIRATION: #{upload_expiration}, UPLOAD_USER_AGENT: #{upload_user_agent.inspect}")
  end

  def debug_log(message)
    warn "[imago-debug] #{message}"
  end

  def run
    @running = true
    while @running
      line = @input.gets
      break if line.nil?

      handle_message(line.strip)
    end
  end

  def stop
    @running = false
  end

  private

  def handle_message(line)
    return if line.empty?

    request = JSON.parse(line)
    response = process_request(request)
    send_response(response) if response
  rescue JSON::ParserError => e
    send_response(error_response(nil, -32_700, "Parse error: #{e.message}"))
  rescue StandardError => e
    send_response(error_response(request&.dig('id'), -32_603, "Internal error: #{e.message}"))
  end

  def process_request(request)
    id = request['id']
    method = request['method']
    params = request['params'] || {}

    case method
    when 'initialize'
      handle_initialize(id, params)
    when 'notifications/initialized'
      nil # No response for notifications
    when 'tools/list'
      handle_tools_list(id)
    when 'tools/call'
      handle_tools_call(id, params)
    when 'ping'
      success_response(id, {})
    else
      error_response(id, -32_601, "Method not found: #{method}")
    end
  end

  def handle_initialize(id, _params)
    success_response(id, {
      protocolVersion: '2024-11-05',
      capabilities: {
        tools: {}
      },
      serverInfo: {
        name: 'imago-mcp',
        version: '1.0.0'
      }
    })
  end

  def handle_tools_list(id)
    success_response(id, { tools: tools })
  end

  def handle_tools_call(id, params)
    tool_name = params['name']
    arguments = params['arguments'] || {}

    result = case tool_name
             when 'generate_image'
               call_generate_image(arguments)
             when 'list_models'
               call_list_models(arguments)
             when 'list_providers'
               call_list_providers
             else
               return error_response(id, -32_602, "Unknown tool: #{tool_name}")
             end

    success_response(id, { content: [{ type: 'text', text: result.to_json }] })
  rescue Imago::AuthenticationError => e
    tool_error_response(id, "Authentication failed: #{e.message}")
  rescue Imago::RateLimitError => e
    tool_error_response(id, "Rate limit exceeded: #{e.message}")
  rescue Imago::InvalidRequestError => e
    tool_error_response(id, "Invalid request: #{e.message}")
  rescue Imago::ApiError => e
    tool_error_response(id, "API error (#{e.status_code}): #{e.message}")
  rescue Imago::ConfigurationError => e
    tool_error_response(id, "Configuration error: #{e.message}")
  rescue Imago::ProviderNotFoundError => e
    tool_error_response(id, "Provider not found: #{e.message}")
  rescue Imago::UnsupportedFeatureError => e
    tool_error_response(id, "Unsupported feature: #{e.message}")
  end

  def available_providers
    SUPPORTED_PROVIDERS.select { |provider| provider_available?(provider) }
  end

  def provider_available?(provider)
    env_var = PROVIDER_ENV_VARS[provider]
    return false unless env_var

    value = ENV.fetch(env_var, nil)
    value && !value.empty?
  end

  def tools
    [
      {
        name: 'generate_image',
        description: 'Generate images from a text prompt using AI image generation services',
        inputSchema: {
          type: 'object',
          properties: {
            provider: {
              type: 'string',
              enum: available_providers.map(&:to_s),
              description: 'The AI provider to use (openai, gemini, or xai)'
            },
            prompt: {
              type: 'string',
              description: 'The text prompt describing the image to generate'
            },
            model: {
              type: 'string',
              description: 'Specific model to use (optional, uses provider default if omitted)'
            },
            n: {
              type: 'integer',
              description: 'Number of images to generate (default: 1)',
              minimum: 1,
              maximum: 10
            },
            size: {
              type: 'string',
              description: 'Image size (OpenAI only): 256x256, 512x512, 1024x1024, 1792x1024, 1024x1792'
            },
            quality: {
              type: 'string',
              enum: %w[standard hd],
              description: 'Image quality (OpenAI only): standard or hd'
            },
            aspect_ratio: {
              type: 'string',
              description: 'Aspect ratio (Gemini only): e.g., 16:9, 4:3, 1:1'
            },
            negative_prompt: {
              type: 'string',
              description: 'Terms to exclude from generation (Gemini only)'
            },
            seed: {
              type: 'integer',
              description: 'Seed for reproducibility (Gemini only)'
            },
            response_format: {
              type: 'string',
              enum: %w[url b64_json],
              description: 'Response format (OpenAI/xAI): url or b64_json'
            },
            images: {
              type: 'array',
              description: 'Input images for image editing (OpenAI/Gemini only). Each item can be: ' \
                           '(1) a URL string, (2) an object with "url" and "mime_type", or ' \
                           '(3) an object with "base64" and "mime_type"',
              items: {
                oneOf: [
                  { type: 'string', description: 'URL of the image (MIME type auto-detected from extension)' },
                  {
                    type: 'object',
                    properties: {
                      url: { type: 'string', description: 'URL of the image' },
                      mime_type: { type: 'string', description: 'MIME type (e.g., image/png, image/jpeg)' }
                    },
                    required: %w[url mime_type]
                  },
                  {
                    type: 'object',
                    properties: {
                      base64: { type: 'string', description: 'Base64-encoded image data' },
                      mime_type: { type: 'string', description: 'MIME type (e.g., image/png, image/jpeg)' }
                    },
                    required: %w[base64 mime_type]
                  }
                ]
              }
            }
          },
          required: %w[provider prompt]
        }
      },
      {
        name: 'list_models',
        description: 'List available image generation models for a provider',
        inputSchema: {
          type: 'object',
          properties: {
            provider: {
              type: 'string',
              enum: available_providers.map(&:to_s),
              description: 'The AI provider to query (openai, gemini, or xai)'
            }
          },
          required: ['provider']
        }
      },
      {
        name: 'list_providers',
        description: 'List all supported image generation providers',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      }
    ]
  end

  def call_generate_image(arguments)
    provider = arguments['provider'].to_sym
    prompt = arguments['prompt']
    model = arguments['model']

    client = create_client(provider: provider, model: model)

    options = build_generate_options(arguments)
    result = client.generate(prompt, options)
    process_generated_images(result)
  end

  def call_list_models(arguments)
    provider = arguments['provider'].to_sym
    client = create_client(provider: provider)
    { provider: provider.to_s, models: client.models }
  end

  def call_list_providers
    { providers: available_providers.map(&:to_s) }
  end

  def create_client(provider:, model: nil)
    Imago.new(provider: provider, model: model)
  end

  def build_generate_options(arguments)
    options = {}
    %w[n size quality aspect_ratio negative_prompt seed response_format].each do |key|
      value = arguments[key]
      options[key.to_sym] = value unless value.nil?
    end

    images = arguments['images']
    options[:images] = normalize_images(images) if images && !images.empty?

    options
  end

  def normalize_images(images)
    images.map do |image|
      if image.is_a?(String)
        image
      else
        image.transform_keys(&:to_sym)
      end
    end
  end

  def upload_enabled?
    url = ENV.fetch('UPLOAD_URL', nil)
    url && !url.empty?
  end

  def upload_url
    ENV.fetch('UPLOAD_URL', nil)
  end

  def upload_expiration
    ENV.fetch('UPLOAD_EXPIRATION', '1').to_i
  end

  def upload_user_agent
    ENV.fetch('UPLOAD_USER_AGENT', DEFAULT_USER_AGENT)
  end

  def process_generated_images(result)
    debug_log("process_generated_images called. upload_enabled?=#{upload_enabled?}")
    unless upload_enabled?
      debug_log('Upload NOT enabled - returning original result')
      return result
    end

    images = result[:images] || result['images']
    debug_log("Found images array: #{images.class}, count: #{images&.length || 'nil'}")
    return result unless images.is_a?(Array)

    processed_images = images.map.with_index do |image, idx|
      debug_log("Processing image #{idx}: keys=#{image.is_a?(Hash) ? image.keys.inspect : image.class}")
      process_single_image(image)
    end

    result_with_sym = result.transform_keys(&:to_sym)
    result_with_sym[:images] = processed_images
    debug_log("Finished processing. Returning #{processed_images.length} images")
    result_with_sym
  end

  def process_single_image(image)
    unless image.is_a?(Hash)
      debug_log("  Image is not a Hash (#{image.class}), skipping upload")
      return image
    end

    image = image.transform_keys(&:to_sym)
    base64_data = image[:b64_json] || image[:base64]

    unless base64_data
      debug_log("  No base64 data found (keys: #{image.keys.inspect}), skipping upload")
      return image
    end

    debug_log("  Found base64 data (#{base64_data.length} chars), attempting upload to #{upload_url}")
    mime_type = image[:mime_type] || 'image/png'
    uploaded_url = upload_to_0x0(base64_data, mime_type)

    if uploaded_url
      debug_log("  Upload SUCCESS: #{uploaded_url}")
      { url: uploaded_url }
    else
      debug_log('  Upload FAILED, keeping original base64 data')
      image
    end
  end

  def upload_to_0x0(base64_data, mime_type)
    binary_data = Base64.decode64(base64_data)
    extension = mime_type_to_extension(mime_type)
    debug_log("  Uploading #{binary_data.length} bytes as .#{extension} to #{upload_url}")

    uri = URI.parse(upload_url)
    boundary = "----RubyFormBoundary#{SecureRandom.hex(16)}"

    body = build_multipart_body(binary_data, extension, boundary)

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request['User-Agent'] = upload_user_agent
    request.body = body

    debug_log("  Sending HTTP POST to #{uri.host}:#{uri.port} (ssl=#{uri.scheme == 'https'}, ua=#{upload_user_agent})")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    debug_log("  Response: #{response.code} - #{response.body[0..100]}")
    response.code.start_with?('2') ? response.body.strip : nil
  rescue StandardError => e
    debug_log("  Upload exception: #{e.class}: #{e.message}")
    nil
  end

  def build_multipart_body(binary_data, extension, boundary)
    body = +''

    # File field
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"image.#{extension}\"\r\n"
    body << "Content-Type: application/octet-stream\r\n\r\n"
    body << binary_data
    body << "\r\n"

    # Secret field (empty but present for longer URLs)
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"secret\"\r\n\r\n"
    body << "\r\n"

    # Expires field
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"expires\"\r\n\r\n"
    body << upload_expiration.to_s
    body << "\r\n"

    body << "--#{boundary}--\r\n"
    body
  end

  def mime_type_to_extension(mime_type)
    MIME_TYPE_EXTENSIONS.fetch(mime_type, 'png')
  end

  def success_response(id, result)
    { jsonrpc: '2.0', id: id, result: result }
  end

  def error_response(id, code, message)
    { jsonrpc: '2.0', id: id, error: { code: code, message: message } }
  end

  def tool_error_response(id, message)
    success_response(id, { content: [{ type: 'text', text: message }], isError: true })
  end

  def send_response(response)
    @output.puts(response.to_json)
    @output.flush
  end
end

# Run the server if executed directly
if __FILE__ == $PROGRAM_NAME
  server = ImagoMcpServer.new
  server.run
end
