# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/generate_options'

RSpec.describe GenerateOptions do
  describe '#build' do
    it 'extracts n option' do
      options = described_class.new({ 'n' => 2 }).build

      expect(options[:n]).to eq(2)
    end

    it 'extracts size option' do
      options = described_class.new({ 'size' => '1024x1024' }).build

      expect(options[:size]).to eq('1024x1024')
    end

    it 'extracts quality option' do
      options = described_class.new({ 'quality' => 'hd' }).build

      expect(options[:quality]).to eq('hd')
    end

    it 'extracts aspect_ratio option' do
      options = described_class.new({ 'aspect_ratio' => '16:9' }).build

      expect(options[:aspect_ratio]).to eq('16:9')
    end

    it 'extracts negative_prompt option' do
      options = described_class.new({ 'negative_prompt' => 'blur' }).build

      expect(options[:negative_prompt]).to eq('blur')
    end

    it 'extracts seed option' do
      options = described_class.new({ 'seed' => 42 }).build

      expect(options[:seed]).to eq(42)
    end

    it 'extracts response_format option' do
      options = described_class.new({ 'response_format' => 'b64_json' }).build

      expect(options[:response_format]).to eq('b64_json')
    end

    it 'ignores nil values' do
      options = described_class.new({ 'n' => nil, 'size' => '512x512' }).build

      expect(options).not_to have_key(:n)
      expect(options[:size]).to eq('512x512')
    end

    it 'ignores unknown options' do
      options = described_class.new({ 'unknown' => 'value' }).build

      expect(options).not_to have_key(:unknown)
    end

    context 'with images' do
      it 'includes URL string images' do
        args = { 'images' => ['https://example.com/img.png'] }
        options = described_class.new(args).build

        expect(options[:images]).to eq(['https://example.com/img.png'])
      end

      it 'converts object images to symbol keys' do
        args = { 'images' => [{ 'base64' => 'data', 'mime_type' => 'image/png' }] }
        options = described_class.new(args).build

        expect(options[:images]).to eq([{ base64: 'data', mime_type: 'image/png' }])
      end

      it 'handles mixed image formats' do
        args = {
          'images' => [
            'https://example.com/img.png',
            { 'url' => 'https://example.com/img2.jpg', 'mime_type' => 'image/jpeg' }
          ]
        }
        options = described_class.new(args).build

        expect(options[:images][0]).to eq('https://example.com/img.png')
        expect(options[:images][1]).to eq({ url: 'https://example.com/img2.jpg', mime_type: 'image/jpeg' })
      end

      it 'excludes images when array is empty' do
        args = { 'images' => [] }
        options = described_class.new(args).build

        expect(options).not_to have_key(:images)
      end

      it 'excludes images when nil' do
        args = { 'images' => nil }
        options = described_class.new(args).build

        expect(options).not_to have_key(:images)
      end
    end

    it 'combines multiple options' do
      args = { 'n' => 2, 'size' => '1024x1024', 'quality' => 'hd' }
      options = described_class.new(args).build

      expect(options).to eq({ n: 2, size: '1024x1024', quality: 'hd' })
    end
  end
end
