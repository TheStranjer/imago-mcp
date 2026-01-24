# frozen_string_literal: true

# Helper module for sending MCP requests in tests
module RequestHelper
  def send_request(request)
    prepare_input(request)
    process_and_respond
  end

  private

  def prepare_input(request)
    input.string = request_json(request)
    input.rewind
  end

  def request_json(request)
    "#{request.to_json}\n"
  end

  def process_and_respond
    process_line
    read_output
  end

  def process_line
    line = input.gets.strip
    server.send(:handle_message, line)
  end

  def read_output
    output.rewind
    JSON.parse(output.read)
  end
end
