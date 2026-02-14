# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/image_uploader'

RSpec.describe ImageUploader do
  subject(:uploader) { described_class.new(config: config) }

  let(:config) do
    instance_double(UploadConfig, url: 'https://0x0.st', expiration: 24, user_agent: 'test/1.0')
  end

  describe '#upload' do
    let(:base64_data) { Base64.encode64('test image data') }
    let(:mime_type) { 'image/png' }

    context 'when upload succeeds' do
      before do
        mock_response = instance_double(Net::HTTPResponse, code: '200', body: "https://0x0.st/abc.png\n")
        allow(Net::HTTP).to receive(:start).and_return(mock_response)
      end

      it 'returns the uploaded URL' do
        result = uploader.upload(base64_data, mime_type)

        expect(result).to eq('https://0x0.st/abc.png')
      end
    end

    context 'when upload fails with non-2xx status' do
      before do
        mock_response = instance_double(Net::HTTPResponse, code: '500', body: 'Internal Server Error')
        allow(Net::HTTP).to receive(:start).and_return(mock_response)
      end

      it 'returns an error hash with status code and body' do
        result = uploader.upload(base64_data, mime_type)

        expect(result).to eq(error: true, status_code: '500', body: 'Internal Server Error')
      end
    end

    context 'when upload fails with 413 status' do
      before do
        mock_response = instance_double(Net::HTTPResponse, code: '413', body: 'File too large')
        allow(Net::HTTP).to receive(:start).and_return(mock_response)
      end

      it 'returns an error hash with the server message' do
        result = uploader.upload(base64_data, mime_type)

        expect(result).to eq(error: true, status_code: '413', body: 'File too large')
      end
    end

    context 'when upload raises an exception' do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      end

      it 'raises the exception' do
        expect { uploader.upload(base64_data, mime_type) }
          .to raise_error(Errno::ECONNREFUSED)
      end
    end
  end

  describe 'MIME type extension mapping' do
    let(:base64_data) { Base64.encode64('test') }

    def capture_body_for_upload(mime_type)
      captured = nil
      allow(Net::HTTP).to receive(:start) do |_host, _port, **_opts, &block|
        mock_http = instance_double(Net::HTTP)
        allow(mock_http).to receive(:request) do |req|
          captured = req.body
          instance_double(Net::HTTPResponse, code: '200', body: 'https://0x0.st/test.png')
        end
        block.call(mock_http)
      end
      uploader.upload(base64_data, mime_type)
      captured
    end

    it 'uses png extension for image/png' do
      body = capture_body_for_upload('image/png')

      expect(body).to include('filename="image.png"')
    end

    it 'uses jpg extension for image/jpeg' do
      body = capture_body_for_upload('image/jpeg')

      expect(body).to include('filename="image.jpg"')
    end

    it 'uses jpg extension for image/jpg' do
      body = capture_body_for_upload('image/jpg')

      expect(body).to include('filename="image.jpg"')
    end

    it 'uses gif extension for image/gif' do
      body = capture_body_for_upload('image/gif')

      expect(body).to include('filename="image.gif"')
    end

    it 'uses webp extension for image/webp' do
      body = capture_body_for_upload('image/webp')

      expect(body).to include('filename="image.webp"')
    end

    it 'defaults to png for unknown mime types' do
      body = capture_body_for_upload('image/unknown')

      expect(body).to include('filename="image.png"')
    end
  end
end
