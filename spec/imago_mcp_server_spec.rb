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

    it 'includes images parameter in generate_image schema' do
      response = send_request({ jsonrpc: '2.0', id: 3, method: 'tools/list', params: {} })

      tools = response.dig('result', 'tools')
      generate_tool = tools.find { |t| t['name'] == 'generate_image' }
      images_schema = generate_tool.dig('inputSchema', 'properties', 'images')

      expect(images_schema['type']).to eq('array')
      expect(images_schema['items']['oneOf']).to be_an(Array)
      expect(images_schema['items']['oneOf'].length).to eq(3)
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

    context 'with image inputs' do
      it 'passes URL string images to generate' do
        allow(Imago).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate).and_return({ images: [] })

        send_request({
          jsonrpc: '2.0',
          id: 20,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: {
              'provider' => 'openai',
              'prompt' => 'make it colorful',
              'images' => ['https://example.com/photo.jpg']
            }
          }
        })

        expect(mock_client).to have_received(:generate).with(
          'make it colorful',
          { images: ['https://example.com/photo.jpg'] }
        )
      end

      it 'passes base64 images with mime_type to generate' do
        allow(Imago).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate).and_return({ images: [] })

        send_request({
          jsonrpc: '2.0',
          id: 21,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: {
              'provider' => 'openai',
              'prompt' => 'add a hat',
              'images' => [{ 'base64' => 'iVBORw0KGgo', 'mime_type' => 'image/png' }]
            }
          }
        })

        expect(mock_client).to have_received(:generate).with(
          'add a hat',
          { images: [{ base64: 'iVBORw0KGgo', mime_type: 'image/png' }] }
        )
      end

      it 'passes URL with explicit mime_type to generate' do
        allow(Imago).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate).and_return({ images: [] })

        send_request({
          jsonrpc: '2.0',
          id: 22,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: {
              'provider' => 'gemini',
              'prompt' => 'edit this',
              'images' => [{ 'url' => 'https://example.com/photo', 'mime_type' => 'image/jpeg' }]
            }
          }
        })

        expect(mock_client).to have_received(:generate).with(
          'edit this',
          { images: [{ url: 'https://example.com/photo', mime_type: 'image/jpeg' }] }
        )
      end

      it 'passes mixed image formats to generate' do
        allow(Imago).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate).and_return({ images: [] })

        send_request({
          jsonrpc: '2.0',
          id: 23,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: {
              'provider' => 'openai',
              'prompt' => 'combine these',
              'images' => [
                'https://example.com/photo1.jpg',
                { 'base64' => 'abc123', 'mime_type' => 'image/png' },
                { 'url' => 'https://example.com/photo2', 'mime_type' => 'image/webp' }
              ]
            }
          }
        })

        expect(mock_client).to have_received(:generate).with(
          'combine these',
          {
            images: [
              'https://example.com/photo1.jpg',
              { base64: 'abc123', mime_type: 'image/png' },
              { url: 'https://example.com/photo2', mime_type: 'image/webp' }
            ]
          }
        )
      end

      it 'does not pass images when array is empty' do
        allow(Imago).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate).and_return({ images: [] })

        send_request({
          jsonrpc: '2.0',
          id: 24,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: {
              'provider' => 'openai',
              'prompt' => 'generate new',
              'images' => []
            }
          }
        })

        expect(mock_client).to have_received(:generate).with('generate new', {})
      end

      it 'passes images alongside other options' do
        allow(Imago).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate).and_return({ images: [] })

        send_request({
          jsonrpc: '2.0',
          id: 25,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: {
              'provider' => 'openai',
              'prompt' => 'edit with options',
              'images' => ['https://example.com/photo.jpg'],
              'n' => 2,
              'size' => '1024x1024'
            }
          }
        })

        expect(mock_client).to have_received(:generate).with(
          'edit with options',
          { n: 2, size: '1024x1024', images: ['https://example.com/photo.jpg'] }
        )
      end
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

    it 'returns tool error for UnsupportedFeatureError' do
      mock_client = double('Imago client') # rubocop:disable RSpec/VerifiedDoubles
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:generate)
        .and_raise(Imago::UnsupportedFeatureError, 'xAI does not support image inputs')

      response = send_request({
        jsonrpc: '2.0',
        id: 26,
        method: 'tools/call',
        params: {
          name: 'generate_image',
          arguments: {
            'provider' => 'xai',
            'prompt' => 'edit this',
            'images' => ['https://example.com/photo.jpg']
          }
        }
      })

      expect(response.dig('result', 'isError')).to be true
      expect(response.dig('result', 'content', 0, 'text')).to match(/Unsupported feature/)
      expect(response.dig('result', 'content', 0, 'text')).to match(/xAI does not support image inputs/)
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

  describe 'image upload to 0x0' do
    let(:mock_client) { double('Imago client') } # rubocop:disable RSpec/VerifiedDoubles

    before do
      allow(Imago).to receive(:new).and_return(mock_client)
    end

    context 'when UPLOAD_URL is not set' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('UPLOAD_URL', nil).and_return(nil)
      end

      it 'returns base64 images unchanged' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'iVBORw0KGgo', mime_type: 'image/png' }]
        })

        response = send_request({
          jsonrpc: '2.0',
          id: 30,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'].first['b64_json']).to eq('iVBORw0KGgo')
      end
    end

    context 'when UPLOAD_URL is empty string' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('UPLOAD_URL', nil).and_return('')
      end

      it 'returns base64 images unchanged' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'iVBORw0KGgo', mime_type: 'image/png' }]
        })

        response = send_request({
          jsonrpc: '2.0',
          id: 31,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'].first['b64_json']).to eq('iVBORw0KGgo')
      end
    end

    context 'when UPLOAD_URL is set' do
      let(:upload_url) { 'https://0x0.st' }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('UPLOAD_URL', nil).and_return(upload_url)
        allow(ENV).to receive(:fetch).with('UPLOAD_EXPIRATION', '1').and_return('24')
      end

      it 'uploads base64 images and returns URLs' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'iVBORw0KGgo', mime_type: 'image/png' }]
        })

        mock_response = instance_double(Net::HTTPResponse, code: '200', body: "https://0x0.st/abc.png\n")
        allow(Net::HTTP).to receive(:start).and_return(mock_response)

        response = send_request({
          jsonrpc: '2.0',
          id: 32,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'].first['url']).to eq('https://0x0.st/abc.png')
        expect(result['images'].first).not_to have_key('b64_json')
      end

      it 'handles base64 key as well as b64_json' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ base64: 'iVBORw0KGgo', mime_type: 'image/png' }]
        })

        mock_response = instance_double(Net::HTTPResponse, code: '200', body: "https://0x0.st/def.png\n")
        allow(Net::HTTP).to receive(:start).and_return(mock_response)

        response = send_request({
          jsonrpc: '2.0',
          id: 33,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'gemini', 'prompt' => 'test' }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'].first['url']).to eq('https://0x0.st/def.png')
      end

      it 'passes through URL images unchanged' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ url: 'https://example.com/existing.png' }]
        })

        response = send_request({
          jsonrpc: '2.0',
          id: 34,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'].first['url']).to eq('https://example.com/existing.png')
      end

      it 'processes multiple images' do
        allow(mock_client).to receive(:generate).and_return({
          images: [
            { b64_json: 'image1data', mime_type: 'image/png' },
            { url: 'https://example.com/existing.png' },
            { b64_json: 'image2data', mime_type: 'image/jpeg' }
          ]
        })

        call_count = 0
        allow(Net::HTTP).to receive(:start) do
          call_count += 1
          instance_double(Net::HTTPResponse, code: '200', body: "https://0x0.st/img#{call_count}.png\n")
        end

        response = send_request({
          jsonrpc: '2.0',
          id: 35,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test', 'n' => 3 }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'][0]['url']).to eq('https://0x0.st/img1.png')
        expect(result['images'][1]['url']).to eq('https://example.com/existing.png')
        expect(result['images'][2]['url']).to eq('https://0x0.st/img2.png')
      end

      it 'keeps original image if upload fails' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'iVBORw0KGgo', mime_type: 'image/png' }]
        })

        mock_response = instance_double(Net::HTTPResponse, code: '500', body: 'Internal Server Error')
        allow(Net::HTTP).to receive(:start).and_return(mock_response)

        response = send_request({
          jsonrpc: '2.0',
          id: 36,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'].first['b64_json']).to eq('iVBORw0KGgo')
      end

      it 'keeps original image if upload raises exception' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'iVBORw0KGgo', mime_type: 'image/png' }]
        })

        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)

        response = send_request({
          jsonrpc: '2.0',
          id: 37,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'].first['b64_json']).to eq('iVBORw0KGgo')
      end

      it 'sends multipart form data with correct content type' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'dGVzdA==', mime_type: 'image/png' }]
        })

        captured_request = nil
        allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
          mock_http = instance_double(Net::HTTP)
          allow(mock_http).to receive(:request) do |req|
            captured_request = req
            instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.png')
          end
          block.call(mock_http)
        end

        send_request({
          jsonrpc: '2.0',
          id: 38,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        expect(captured_request).not_to be_nil
        expect(captured_request['Content-Type']).to match(%r{multipart/form-data; boundary=})
      end

      it 'includes file, secret, and expires fields in multipart body' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'dGVzdA==', mime_type: 'image/png' }]
        })

        captured_body = nil
        allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
          mock_http = instance_double(Net::HTTP)
          allow(mock_http).to receive(:request) do |req|
            captured_body = req.body
            instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.png')
          end
          block.call(mock_http)
        end

        send_request({
          jsonrpc: '2.0',
          id: 38,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        expect(captured_body).to include('name="file"', 'name="secret"', 'name="expires"', '24')
      end

      it 'uses default expiration of 1 hour when not set' do
        allow(ENV).to receive(:fetch).with('UPLOAD_EXPIRATION', '1').and_return('1')

        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'dGVzdA==', mime_type: 'image/png' }]
        })

        captured_body = nil
        allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
          mock_http = instance_double(Net::HTTP)
          allow(mock_http).to receive(:request) do |req|
            captured_body = req.body
            instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.png')
          end
          block.call(mock_http)
        end

        send_request({
          jsonrpc: '2.0',
          id: 39,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        expect(captured_body).to include("name=\"expires\"\r\n\r\n1\r\n")
      end

      it 'uses correct extension for png mime type' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'dGVzdA==', mime_type: 'image/png' }]
        })

        captured_body = nil
        allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
          mock_http = instance_double(Net::HTTP)
          allow(mock_http).to receive(:request) do |req|
            captured_body = req.body
            instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.png')
          end
          block.call(mock_http)
        end

        send_request({
          jsonrpc: '2.0',
          id: 40,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        expect(captured_body).to include('filename="image.png"')
      end

      it 'uses correct extension for jpeg mime type' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'dGVzdA==', mime_type: 'image/jpeg' }]
        })

        captured_body = nil
        allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
          mock_http = instance_double(Net::HTTP)
          allow(mock_http).to receive(:request) do |req|
            captured_body = req.body
            instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.jpg')
          end
          block.call(mock_http)
        end

        send_request({
          jsonrpc: '2.0',
          id: 41,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        expect(captured_body).to include('filename="image.jpg"')
      end

      it 'defaults to png extension for unknown mime type' do
        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'dGVzdA==', mime_type: 'image/unknown' }]
        })

        captured_body = nil
        allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
          mock_http = instance_double(Net::HTTP)
          allow(mock_http).to receive(:request) do |req|
            captured_body = req.body
            instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.png')
          end
          block.call(mock_http)
        end

        send_request({
          jsonrpc: '2.0',
          id: 42,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        expect(captured_body).to include('filename="image.png"')
      end

      it 'handles string keys in result' do
        allow(mock_client).to receive(:generate).and_return({
          'images' => [{ 'b64_json' => 'iVBORw0KGgo', 'mime_type' => 'image/png' }]
        })

        mock_response = instance_double(Net::HTTPResponse, code: '200', body: "https://0x0.st/str.png\n")
        allow(Net::HTTP).to receive(:start).and_return(mock_response)

        response = send_request({
          jsonrpc: '2.0',
          id: 50,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        content = response.dig('result', 'content', 0, 'text')
        result = JSON.parse(content)

        expect(result['images'].first['url']).to eq('https://0x0.st/str.png')
      end

      it 'uses default curl user agent when UPLOAD_USER_AGENT not set' do
        allow(ENV).to receive(:fetch).with('UPLOAD_USER_AGENT', 'curl/8.5.0').and_return('curl/8.5.0')

        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'dGVzdA==', mime_type: 'image/png' }]
        })

        captured_request = nil
        allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
          mock_http = instance_double(Net::HTTP)
          allow(mock_http).to receive(:request) do |req|
            captured_request = req
            instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.png')
          end
          block.call(mock_http)
        end

        send_request({
          jsonrpc: '2.0',
          id: 51,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        expect(captured_request['User-Agent']).to eq('curl/8.5.0')
      end

      it 'uses custom user agent when UPLOAD_USER_AGENT is set' do
        allow(ENV).to receive(:fetch).with('UPLOAD_USER_AGENT', 'curl/8.5.0').and_return('MyCustomAgent/1.0')

        allow(mock_client).to receive(:generate).and_return({
          images: [{ b64_json: 'dGVzdA==', mime_type: 'image/png' }]
        })

        captured_request = nil
        allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
          mock_http = instance_double(Net::HTTP)
          allow(mock_http).to receive(:request) do |req|
            captured_request = req
            instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.png')
          end
          block.call(mock_http)
        end

        send_request({
          jsonrpc: '2.0',
          id: 52,
          method: 'tools/call',
          params: {
            name: 'generate_image',
            arguments: { 'provider' => 'openai', 'prompt' => 'test' }
          }
        })

        expect(captured_request['User-Agent']).to eq('MyCustomAgent/1.0')
      end
    end
  end
end
