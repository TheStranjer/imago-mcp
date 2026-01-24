# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/multipart_builder'

RSpec.describe MultipartBuilder do
  subject(:builder) { described_class.new }

  describe '#boundary' do
    it 'generates a unique boundary' do
      expect(builder.boundary).to match(/^----RubyFormBoundary[a-f0-9]{32}$/)
    end

    it 'generates different boundaries for different instances' do
      other = described_class.new
      expect(builder.boundary).not_to eq(other.boundary)
    end
  end

  describe '#content_type' do
    it 'returns multipart/form-data with boundary' do
      expect(builder.content_type).to eq("multipart/form-data; boundary=#{builder.boundary}")
    end
  end

  describe '#build' do
    let(:binary_data) { 'test binary data' }
    let(:extension) { 'png' }
    let(:expiration) { 24 }

    it 'includes file field with correct filename' do
      body = builder.build(binary_data, extension, expiration)

      expect(body).to include('name="file"')
      expect(body).to include('filename="image.png"')
    end

    it 'includes the binary data' do
      body = builder.build(binary_data, extension, expiration)

      expect(body).to include(binary_data)
    end

    it 'includes secret field' do
      body = builder.build(binary_data, extension, expiration)

      expect(body).to include('name="secret"')
    end

    it 'includes expires field with expiration value' do
      body = builder.build(binary_data, extension, expiration)

      expect(body).to include('name="expires"')
      expect(body).to include("24\r\n")
    end

    it 'includes proper boundary markers' do
      body = builder.build(binary_data, extension, expiration)

      expect(body).to include("--#{builder.boundary}\r\n")
      expect(body).to include("--#{builder.boundary}--\r\n")
    end

    it 'can be called multiple times' do
      body1 = builder.build('data1', 'png', 1)
      body2 = builder.build('data2', 'jpg', 2)

      expect(body1).to include('data1')
      expect(body2).to include('data2')
      expect(body2).not_to include('data1')
    end
  end
end
