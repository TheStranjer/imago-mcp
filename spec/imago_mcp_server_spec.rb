# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'stringio'

RSpec.describe ImagoMcpServer do
  subject(:server) { described_class.new(input: input, output: output) }

  let(:input) { StringIO.new }
  let(:output) { StringIO.new }

  def send_request(request)
    input.string = "#{request.to_json}\n"
    input.rewind
    server.send(:handle_message, input.gets.strip)
    output.rewind
    JSON.parse(output.read)
  end

  describe '#initialize' do
    it 'returns server info with protocol version' do
      response = send_request({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {} })

      expect(response['jsonrpc']).to eq('2.0')
      expect(response['id']).to eq(1)
      expect(response.dig('result', 'protocolVersion')).to eq('2024-11-05')
      expect(response.dig('result', 'serverInfo', 'name')).to eq('imago-mcp')
    end

    it 'returns tools capability' do
      response = send_request({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {} })

      expect(response.dig('result', 'capabilities', 'tools')).to be_a(Hash)
    end
  end

  describe 'tools/list' do
    it 'returns all available tools' do
      response = send_request({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} })

      tools = response.dig('result', 'tools')
      tool_names = tools.map { |t| t['name'] }

      expect(tool_names).to include('generate_image', 'list_models', 'list_providers')
    end

    it 'includes correct schema for generate_image tool' do
      response = send_request({ jsonrpc: '2.0', id: 3, method: 'tools/list', params: {} })

      tools = response.dig('result', 'tools')
      generate_tool = tools.find { |t| t['name'] == 'generate_image' }

      expect(generate_tool.dig('inputSchema', 'type')).to eq('object')
      expect(generate_tool.dig('inputSchema', 'required')).to include('provider', 'prompt')
    end

    context 'when only some providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-openai-key')
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return('test-xai-key')
      end

      it 'only includes configured providers in generate_image enum' do
        response = send_request({ jsonrpc: '2.0', id: 3, method: 'tools/list', params: {} })

        tools = response.dig('result', 'tools')
        generate_tool = tools.find { |t| t['name'] == 'generate_image' }
        provider_enum = generate_tool.dig('inputSchema', 'properties', 'provider', 'enum')

        expect(provider_enum).to contain_exactly('openai', 'xai')
        expect(provider_enum).not_to include('gemini')
      end

      it 'only includes configured providers in list_models enum' do
        response = send_request({ jsonrpc: '2.0', id: 3, method: 'tools/list', params: {} })

        tools = response.dig('result', 'tools')
        list_models_tool = tools.find { |t| t['name'] == 'list_models' }
        provider_enum = list_models_tool.dig('inputSchema', 'properties', 'provider', 'enum')

        expect(provider_enum).to contain_exactly('openai', 'xai')
        expect(provider_enum).not_to include('gemini')
      end
    end

    context 'when all providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-openai-key')
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return('test-gemini-key')
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return('test-xai-key')
      end

      it 'includes all providers in generate_image enum' do
        response = send_request({ jsonrpc: '2.0', id: 3, method: 'tools/list', params: {} })

        tools = response.dig('result', 'tools')
        generate_tool = tools.find { |t| t['name'] == 'generate_image' }
        provider_enum = generate_tool.dig('inputSchema', 'properties', 'provider', 'enum')

        expect(provider_enum).to contain_exactly('openai', 'gemini', 'xai')
      end
    end

    context 'when no providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return(nil)
      end

      it 'returns empty provider enum in generate_image' do
        response = send_request({ jsonrpc: '2.0', id: 3, method: 'tools/list', params: {} })

        tools = response.dig('result', 'tools')
        generate_tool = tools.find { |t| t['name'] == 'generate_image' }
        provider_enum = generate_tool.dig('inputSchema', 'properties', 'provider', 'enum')

        expect(provider_enum).to be_empty
      end
    end
  end

  describe 'tools/call list_providers' do
    context 'when all providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-openai-key')
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return('test-gemini-key')
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return('test-xai-key')
      end

      it 'returns all supported providers' do
        response = send_request({
          jsonrpc: '2.0',
          id: 4,
          method: 'tools/call',
          params: { name: 'list_providers', arguments: {} }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['providers']).to contain_exactly('openai', 'gemini', 'xai')
      end
    end

    context 'when only some providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-openai-key')
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return('test-xai-key')
      end

      it 'returns only configured providers' do
        response = send_request({
          jsonrpc: '2.0',
          id: 4,
          method: 'tools/call',
          params: { name: 'list_providers', arguments: {} }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['providers']).to contain_exactly('openai', 'xai')
        expect(result['providers']).not_to include('gemini')
      end
    end

    context 'when no providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return(nil)
      end

      it 'returns empty providers list' do
        response = send_request({
          jsonrpc: '2.0',
          id: 4,
          method: 'tools/call',
          params: { name: 'list_providers', arguments: {} }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['providers']).to be_empty
      end
    end

    context 'when provider has empty string for API key' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('')
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return('test-gemini-key')
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return(nil)
      end

      it 'treats empty string as unavailable' do
        response = send_request({
          jsonrpc: '2.0',
          id: 4,
          method: 'tools/call',
          params: { name: 'list_providers', arguments: {} }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['providers']).to contain_exactly('gemini')
      end
    end
  end

  describe 'tools/call generate_image' do
    let(:mock_client) { double('Imago client') } # rubocop:disable RSpec/VerifiedDoubles

    it 'invokes Imago.new with the correct provider' do
      allow(mock_client).to receive(:generate).and_return({ images: [] })
      allow(Imago).to receive(:new).with(provider: :openai, model: nil).and_return(mock_client)

      send_request({
        jsonrpc: '2.0',
        id: 5,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: { 'provider' => 'openai', 'prompt' => 'test prompt' }
        }
      })

      expect(Imago).to have_received(:new).with(provider: :openai, model: nil)
    end

    it 'invokes Imago.new with the specified model' do
      allow(mock_client).to receive(:generate).and_return({ images: [] })
      allow(Imago).to receive(:new).with(provider: :openai, model: 'dall-e-3').and_return(mock_client)

      send_request({
        jsonrpc: '2.0',
        id: 6,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: { 'provider' => 'openai', 'prompt' => 'a cat', 'model' => 'dall-e-3' }
        }
      })

      expect(Imago).to have_received(:new).with(provider: :openai, model: 'dall-e-3')
    end

    it 'passes the prompt to generate' do
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:generate).and_return({ images: [] })

      send_request({
        jsonrpc: '2.0',
        id: 7,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: { 'provider' => 'openai', 'prompt' => 'a sunset' }
        }
      })

      expect(mock_client).to have_received(:generate).with('a sunset', {})
    end

    it 'passes OpenAI options to generate' do
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:generate).and_return({ images: [] })

      send_request({
        jsonrpc: '2.0',
        id: 8,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: {
            'provider' => 'openai',
            'prompt' => 'landscape',
            'n' => 2,
            'size' => '1024x1024',
            'quality' => 'hd'
          }
        }
      })

      expect(mock_client).to have_received(:generate).with(
        'landscape',
        { n: 2, size: '1024x1024', quality: 'hd' }
      )
    end

    it 'passes Gemini options to generate' do
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:generate).and_return({ images: [] })

      send_request({
        jsonrpc: '2.0',
        id: 9,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: {
            'provider' => 'gemini',
            'prompt' => 'art',
            'aspect_ratio' => '16:9',
            'negative_prompt' => 'blur',
            'seed' => 42
          }
        }
      })

      expect(mock_client).to have_received(:generate).with(
        'art',
        { aspect_ratio: '16:9', negative_prompt: 'blur', seed: 42 }
      )
    end

    it 'returns the generate result as JSON' do
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:generate).and_return({ images: [{ url: 'https://example.com/image.png' }] })

      response = send_request({
        jsonrpc: '2.0',
        id: 10,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: { 'provider' => 'openai', 'prompt' => 'test' }
        }
      })

      content = response.dig('result', 'content', 0, 'text')
      result = JSON.parse(content)

      expect(result['images'].first['url']).to eq('https://example.com/image.png')
    end
  end

  describe 'tools/call list_models' do
    let(:mock_client) { double('Imago client') } # rubocop:disable RSpec/VerifiedDoubles

    it 'invokes Imago.new with the correct provider' do
      allow(mock_client).to receive(:models).and_return(%w[dall-e-3 dall-e-2])
      allow(Imago).to receive(:new).with(provider: :openai, model: nil).and_return(mock_client)

      send_request({
        jsonrpc: '2.0',
        id: 11,
        method: 'tools/call',
        params: { name: 'list_models', arguments: { 'provider' => 'openai' } }
      })

      expect(Imago).to have_received(:new).with(provider: :openai, model: nil)
    end

    it 'invokes models on the client' do
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:models).and_return(['imagen-3.0-generate-002'])

      send_request({
        jsonrpc: '2.0',
        id: 12,
        method: 'tools/call',
        params: { name: 'list_models', arguments: { 'provider' => 'gemini' } }
      })

      expect(mock_client).to have_received(:models)
    end

    it 'returns the models list' do
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:models).and_return(%w[grok-2-image grok-2-image-1212])

      response = send_request({
        jsonrpc: '2.0',
        id: 13,
        method: 'tools/call',
        params: { name: 'list_models', arguments: { 'provider' => 'xai' } }
      })

      content = response.dig('result', 'content', 0, 'text')
      result = JSON.parse(content)

      expect(result['provider']).to eq('xai')
      expect(result['models']).to eq(%w[grok-2-image grok-2-image-1212])
    end
  end

  describe 'error handling' do
    it 'returns tool error for AuthenticationError' do
      allow(Imago).to receive(:new).and_raise(Imago::AuthenticationError, 'Invalid API key')

      response = send_request({
        jsonrpc: '2.0',
        id: 14,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: { 'provider' => 'openai', 'prompt' => 'test' }
        }
      })

      expect(response.dig('result', 'isError')).to be true
      expect(response.dig('result', 'content', 0, 'text')).to match(/Authentication failed/)
    end

    it 'returns tool error for RateLimitError' do
      allow(Imago).to receive(:new).and_raise(Imago::RateLimitError, 'Too many requests')

      response = send_request({
        jsonrpc: '2.0',
        id: 15,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: { 'provider' => 'openai', 'prompt' => 'test' }
        }
      })

      expect(response.dig('result', 'isError')).to be true
      expect(response.dig('result', 'content', 0, 'text')).to match(/Rate limit exceeded/)
    end

    it 'returns tool error for InvalidRequestError' do
      allow(Imago).to receive(:new).and_raise(Imago::InvalidRequestError, 'Bad request')

      response = send_request({
        jsonrpc: '2.0',
        id: 16,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: { 'provider' => 'openai', 'prompt' => 'test' }
        }
      })

      expect(response.dig('result', 'isError')).to be true
      expect(response.dig('result', 'content', 0, 'text')).to match(/Invalid request/)
    end

    it 'returns error for unknown tool' do
      response = send_request({
        jsonrpc: '2.0',
        id: 17,
        method: 'tools/call',
        params: { name: 'unknown_tool', arguments: {} }
      })

      expect(response.dig('error', 'code')).to eq(-32_602)
      expect(response.dig('error', 'message')).to match(/Unknown tool/)
    end

    it 'returns error for unknown method' do
      response = send_request({ jsonrpc: '2.0', id: 18, method: 'unknown/method', params: {} })

      expect(response.dig('error', 'code')).to eq(-32_601)
    end

    it 'returns parse error for invalid JSON' do
      input.string = "not valid json\n"
      input.rewind
      server.send(:handle_message, input.gets.strip)
      output.rewind
      response = JSON.parse(output.read)

      expect(response.dig('error', 'code')).to eq(-32_700)
    end
  end

  describe 'ping' do
    it 'returns empty response' do
      response = send_request({ jsonrpc: '2.0', id: 19, method: 'ping', params: {} })

      expect(response['result']).to eq({})
    end
  end
end
