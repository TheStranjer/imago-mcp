# frozen_string_literal: true

require_relative 'mcp_response'

# Builds the appropriate MCP response for a tool result
class ToolResultBuilder
  include McpResponse

  def initialize(router, id, result)
    @router = router
    @id = id
    @result = result
  end

  def build
    return tool_success unless @result.is_a?(Hash)

    build_from_hash
  end

  private

  def build_from_hash
    return dispatch_error if @result[:error]

    error_or_success
  end

  def error_or_success
    return tool_error if @result[:tool_error]

    tool_success
  end

  def dispatch_error
    error_response(@id, @result[:code], @result[:message])
  end

  def tool_error
    tool_error_response(@id, @result[:message])
  end

  def tool_success
    content = [{ type: 'text', text: @result.to_json }]
    success_response(@id, { content: content })
  end
end
