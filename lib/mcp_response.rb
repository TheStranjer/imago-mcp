# frozen_string_literal: true

# Builds JSON-RPC 2.0 responses for MCP protocol
module McpResponse
  def success_response(id, result)
    { jsonrpc: '2.0', id: id, result: result }
  end

  def error_response(id, code, message)
    build_error(id, code, message)
  end

  def tool_error_response(id, message)
    content = [{ type: 'text', text: message }]
    success_response(id, build_tool_error(content))
  end

  private

  def build_error(id, code, message)
    { jsonrpc: '2.0', id: id, error: { code: code, message: message } }
  end

  def build_tool_error(content)
    { content: content, isError: true }
  end
end
