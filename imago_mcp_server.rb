#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative 'lib/mcp_response'
require_relative 'lib/request_router'
require_relative 'lib/upload_config'

# MCP Server for the Imago gem - provides image generation through multiple AI providers
class ImagoMcpServer
  include McpResponse

  VERSION = '1.0.0'

  def initialize(input: $stdin, output: $stdout, router: nil)
    @input = input
    @output = output
    @running = false
    @router = router || RequestRouter.new
    log_initialization
  end

  def run
    @running = true
    process_messages while @running
  end

  def stop
    @running = false
  end

  def debug_log(message)
    warn "[imago-debug] #{message}"
  end

  private

  def log_initialization
    debug_log(init_message)
  end

  def init_message
    config = UploadConfig.new
    format_init_message(config)
  end

  def format_init_message(config)
    "#{url_part(config)}, #{exp_part(config)}, #{ua_part(config)}"
  end

  def url_part(config)
    "Server initialized. UPLOAD_URL: #{config.url.inspect}"
  end

  def exp_part(config)
    "UPLOAD_EXPIRATION: #{config.expiration}"
  end

  def ua_part(config)
    "UPLOAD_USER_AGENT: #{config.user_agent.inspect}"
  end

  def process_messages
    line = @input.gets
    line.nil? ? stop : handle_line(line)
  end

  def handle_line(line)
    handle_message(line.strip)
  end

  def handle_message(line)
    return if line.empty?

    process_json(line)
  rescue JSON::ParserError => e
    send_parse_error(e)
  end

  def process_json(line)
    request = JSON.parse(line)
    route_request(request)
  end

  def route_request(request)
    response = @router.route(request)
    send_response(response) if response
  rescue StandardError => e
    send_internal_error(request['id'], e)
  end

  def send_parse_error(error)
    msg = "Parse error: #{error.message}"
    send_response(error_response(nil, -32_700, msg))
  end

  def send_internal_error(id, error)
    msg = "Internal error: #{error.message}"
    send_response(error_response(id, -32_603, msg))
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
