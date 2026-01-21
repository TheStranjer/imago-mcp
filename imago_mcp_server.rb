#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'imago'

# MCP Server for the Imago gem - provides image generation through multiple AI providers
class ImagoMcpServer
  SUPPORTED_PROVIDERS = %i[openai gemini xai].freeze
  PROVIDER_ENV_VARS = {
    openai: 'OPENAI_API_KEY',
    gemini: 'GEMINI_API_KEY',
    xai: 'XAI_API_KEY'
  }.freeze

  def initialize(input: $stdin, output: $stdout)
    @input = input
    @output = output
    @running = false
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
    client.generate(prompt, options)
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
    options
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
