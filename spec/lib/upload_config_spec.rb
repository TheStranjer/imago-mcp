# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/upload_config'

RSpec.describe UploadConfig do
  subject(:config) { described_class.new }

  describe '#enabled?' do
    context 'when UPLOAD_URL is set' do
      before do
        allow(ENV).to receive(:fetch).with('UPLOAD_URL', nil).and_return('https://0x0.st')
      end

      it 'returns true' do
        expect(config.enabled?).to be true
      end
    end

    context 'when UPLOAD_URL is empty' do
      before do
        allow(ENV).to receive(:fetch).with('UPLOAD_URL', nil).and_return('')
      end

      it 'returns false' do
        expect(config.enabled?).to be false
      end
    end

    context 'when UPLOAD_URL is not set' do
      before do
        allow(ENV).to receive(:fetch).with('UPLOAD_URL', nil).and_return(nil)
      end

      it 'returns falsey' do
        expect(config).not_to be_enabled
      end
    end
  end

  describe '#url' do
    it 'returns the UPLOAD_URL environment variable' do
      allow(ENV).to receive(:fetch).with('UPLOAD_URL', nil).and_return('https://example.com')

      expect(config.url).to eq('https://example.com')
    end
  end

  describe '#expiration' do
    context 'when UPLOAD_EXPIRATION is set' do
      before do
        allow(ENV).to receive(:fetch).with('UPLOAD_EXPIRATION', '1').and_return('24')
      end

      it 'returns the configured value as integer' do
        expect(config.expiration).to eq(24)
      end
    end

    context 'when UPLOAD_EXPIRATION is not set' do
      before do
        allow(ENV).to receive(:fetch).with('UPLOAD_EXPIRATION', '1').and_return('1')
      end

      it 'returns the default value of 1' do
        expect(config.expiration).to eq(1)
      end
    end
  end

  describe '#user_agent' do
    context 'when UPLOAD_USER_AGENT is set' do
      before do
        allow(ENV).to receive(:fetch)
          .with('UPLOAD_USER_AGENT', described_class::DEFAULT_USER_AGENT)
          .and_return('CustomAgent/1.0')
      end

      it 'returns the custom user agent' do
        expect(config.user_agent).to eq('CustomAgent/1.0')
      end
    end

    context 'when UPLOAD_USER_AGENT is not set' do
      before do
        allow(ENV).to receive(:fetch)
          .with('UPLOAD_USER_AGENT', described_class::DEFAULT_USER_AGENT)
          .and_return(described_class::DEFAULT_USER_AGENT)
      end

      it 'returns the default user agent' do
        expect(config.user_agent).to eq('imago-mcp/1.0.0')
      end
    end
  end
end
