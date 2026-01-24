# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/tool_handlers'

RSpec.describe ToolHandlers do
  subject(:handlers) { described_class.new(provider_config: provider_config, image_processor: image_processor) }

  let(:provider_config) { instance_double(ProviderConfig) }
  let(:image_processor) { instance_double(ImageProcessor) }
  let(:mock_client) { double('Imago client') } # rubocop:disable RSpec/VerifiedDoubles

  describe '#generate_image' do
    let(:arguments) { { 'provider' => 'openai', 'prompt' => 'test', 'model' => 'dall-e-3' } }

    before do
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:generate).and_return({ images: [] })
      allow(image_processor).to receive(:process).and_return({ images: [] })
    end

    it 'creates client with provider and model' do
      handlers.generate_image(arguments)

      expect(Imago).to have_received(:new).with(provider: :openai, model: 'dall-e-3')
    end

    it 'passes prompt to generate' do
      handlers.generate_image(arguments)

      expect(mock_client).to have_received(:generate).with('test', {})
    end

    it 'passes options to generate' do
      args = arguments.merge('n' => 2, 'size' => '1024x1024')
      handlers.generate_image(args)

      expect(mock_client).to have_received(:generate).with('test', { n: 2, size: '1024x1024' })
    end

    it 'processes result through image processor' do
      result = { images: [{ url: 'https://example.com/img.png' }] }
      allow(mock_client).to receive(:generate).and_return(result)
      allow(image_processor).to receive(:process).and_return(result)

      handlers.generate_image(arguments)

      expect(image_processor).to have_received(:process).with(result)
    end

    it 'returns processed result' do
      processed = { images: [{ url: 'https://0x0.st/abc.png' }] }
      allow(image_processor).to receive(:process).and_return(processed)

      result = handlers.generate_image(arguments)

      expect(result).to eq(processed)
    end
  end

  describe '#list_models' do
    let(:arguments) { { 'provider' => 'gemini' } }

    before do
      allow(Imago).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:models).and_return(%w[model1 model2])
    end

    it 'creates client with provider' do
      handlers.list_models(arguments)

      expect(Imago).to have_received(:new).with(provider: :gemini, model: nil)
    end

    it 'returns provider and models' do
      result = handlers.list_models(arguments)

      expect(result).to eq({ provider: 'gemini', models: %w[model1 model2] })
    end
  end

  describe '#list_providers' do
    before do
      allow(provider_config).to receive(:available_providers).and_return(%i[openai xai])
    end

    it 'returns available providers as strings' do
      result = handlers.list_providers

      expect(result).to eq({ providers: %w[openai xai] })
    end
  end
end
