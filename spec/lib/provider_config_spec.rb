# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/provider_config'

RSpec.describe ProviderConfig do
  subject(:config) { described_class.new }

  describe '#available_providers' do
    context 'when all providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('key1')
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return('key2')
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return('key3')
      end

      it 'returns all providers' do
        expect(config.available_providers).to contain_exactly(:openai, :gemini, :xai)
      end
    end

    context 'when some providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('key1')
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return('key3')
      end

      it 'returns only configured providers' do
        expect(config.available_providers).to contain_exactly(:openai, :xai)
      end
    end

    context 'when no providers are configured' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return(nil)
      end

      it 'returns empty array' do
        expect(config.available_providers).to be_empty
      end
    end
  end

  describe '#available?' do
    context 'when provider has API key set' do
      before do
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('key')
      end

      it 'returns true' do
        expect(config.available?(:openai)).to be true
      end
    end

    context 'when provider has empty API key' do
      before do
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('')
      end

      it 'returns false' do
        expect(config.available?(:openai)).to be false
      end
    end

    context 'when provider has no API key' do
      before do
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
      end

      it 'returns falsey' do
        expect(config.available?(:openai)).to be_falsey # rubocop:disable RSpec/PredicateMatcher
      end
    end

    context 'when provider is unknown' do
      it 'returns false' do
        expect(config.available?(:unknown)).to be false
      end
    end
  end
end
