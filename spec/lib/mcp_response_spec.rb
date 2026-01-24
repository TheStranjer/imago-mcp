# frozen_string_literal: true

require 'spec_helper'

RSpec.describe McpResponse do
  let(:test_class) { Class.new { include McpResponse } }
  let(:instance) { test_class.new }

  describe '#success_response' do
    it 'returns a JSON-RPC 2.0 success response' do
      result = instance.success_response(1, { data: 'test' })

      expect(result[:jsonrpc]).to eq('2.0')
      expect(result[:id]).to eq(1)
      expect(result[:result]).to eq({ data: 'test' })
    end

    it 'handles nil id' do
      result = instance.success_response(nil, {})

      expect(result[:id]).to be_nil
    end
  end

  describe '#error_response' do
    it 'returns a JSON-RPC 2.0 error response' do
      result = instance.error_response(1, -32_600, 'Invalid request')

      expect(result[:jsonrpc]).to eq('2.0')
      expect(result[:id]).to eq(1)
      expect(result[:error][:code]).to eq(-32_600)
      expect(result[:error][:message]).to eq('Invalid request')
    end
  end

  describe '#tool_error_response' do
    it 'returns a success response with isError flag' do
      result = instance.tool_error_response(1, 'Tool failed')

      expect(result[:jsonrpc]).to eq('2.0')
      expect(result[:result][:isError]).to be true
      expect(result[:result][:content]).to eq([{ type: 'text', text: 'Tool failed' }])
    end
  end
end
