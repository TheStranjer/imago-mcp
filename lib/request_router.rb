# frozen_string_literal: true

require_relative 'mcp_response'
require_relative 'tools_schema'
require_relative 'tool_handlers'

# Routes MCP requests to appropriate handlers
class RequestRouter
  include McpResponse

  VERSION = '1.0.0'
  TOOL_METHODS = {
    'tools/list' => :handle_tools_list,
    'tools/call' => :handle_tools_call,
    'ping' => :handle_ping
  }.freeze
  TOOL_HANDLERS = %w[generate_image list_models list_providers].freeze

  def initialize(tools_schema: nil, tool_handlers: nil)
    @tools_schema = tools_schema || ToolsSchema.new
    @tool_handlers = tool_handlers || ToolHandlers.new
  end

  def route(request)
    method = request['method']
    dispatch_method(method, request)
  end

  private

  def dispatch_method(method, request)
    return handle_init(request['id']) if method == 'initialize'
    return nil if method == 'notifications/initialized'

    dispatch_other(method, request)
  end

  def dispatch_other(method, request)
    id = request['id']
    params = request['params'] || {}
    route_by_method(method, id, params)
  end

  def route_by_method(method, id, params)
    handler = TOOL_METHODS[method]
    return send(handler, id, params) if handler

    method_not_found(id, method)
  end

  def handle_ping(id, _params)
    success_response(id, {})
  end

  def method_not_found(id, method)
    error_response(id, -32_601, "Method not found: #{method}")
  end

  def handle_init(id)
    success_response(id, init_result)
  end

  def init_result
    {
      protocolVersion: '2024-11-05',
      capabilities: { tools: {} },
      serverInfo: { name: 'imago-mcp', version: VERSION }
    }
  end

  def handle_tools_list(id, _params)
    success_response(id, { tools: @tools_schema.all })
  end

  def handle_tools_call(id, params)
    result = execute_tool(params)
    format_tool_result(id, result)
  rescue Imago::Error => e
    tool_error_response(id, format_error(e))
  end

  def format_tool_result(id, result)
    return build_dispatch_error(id, result) if dispatch_error?(result)
    return tool_error_response(id, result[:message]) if tool_error?(result)

    build_tool_success(id, result)
  end

  def execute_tool(params)
    name = params['name']
    args = params['arguments'] || {}
    dispatch_tool(name, args)
  end

  def dispatch_tool(name, args)
    return unknown_tool(name) unless valid_tool?(name)

    send("call_#{name}", args)
  end

  def valid_tool?(name)
    TOOL_HANDLERS.include?(name)
  end

  def call_generate_image(args)
    @tool_handlers.generate_image(args)
  end

  def call_list_models(args)
    @tool_handlers.list_models(args)
  end

  def call_list_providers(_args)
    @tool_handlers.list_providers
  end

  def unknown_tool(name)
    { error: true, code: -32_602, message: "Unknown tool: #{name}" }
  end

  def dispatch_error?(result)
    result.is_a?(Hash) && result[:error]
  end

  def tool_error?(result)
    result.is_a?(Hash) && result[:tool_error]
  end

  def build_dispatch_error(id, result)
    error_response(id, result[:code], result[:message])
  end

  def build_tool_success(id, result)
    content = [{ type: 'text', text: result.to_json }]
    success_response(id, { content: content })
  end

  def format_error(error)
    formatter = ErrorFormatter.new(error)
    formatter.format
  end
end

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
