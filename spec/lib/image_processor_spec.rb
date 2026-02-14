# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/image_processor'

RSpec.describe ImageProcessor do
  subject(:processor) { described_class.new(config: config, uploader: uploader) }

  let(:config) { instance_double(UploadConfig) }
  let(:uploader) { instance_double(ImageUploader) }

  describe '#process' do
    context 'when upload is disabled' do
      before do
        allow(config).to receive(:enabled?).and_return(false)
      end

      it 'returns the result unchanged' do
        result = { images: [{ b64_json: 'data' }] }
        processed = processor.process(result)

        expect(processed).to eq(result)
      end
    end

    context 'when images array is empty' do
      it 'returns an error regardless of upload config' do
        allow(config).to receive(:enabled?).and_return(false)
        result = { images: [] }

        processed = processor.process(result)

        expect(processed).to eq(
          error: true,
          code: -32_602,
          message: 'Image generation produced no images. Verify the model supports image generation using list_models.'
        )
      end

      it 'returns an error with string keys' do
        allow(config).to receive(:enabled?).and_return(true)
        result = { 'images' => [] }

        processed = processor.process(result)

        expect(processed[:error]).to be true
        expect(processed[:message]).to include('no images')
      end
    end

    context 'when upload is enabled' do
      before do
        allow(config).to receive(:enabled?).and_return(true)
      end

      context 'when result has no images array' do
        it 'returns the result unchanged' do
          result = { data: 'something' }
          processed = processor.process(result)

          expect(processed).to eq(result)
        end
      end

      context 'when images is not an array' do
        it 'returns the result unchanged' do
          result = { images: 'not an array' }
          processed = processor.process(result)

          expect(processed).to eq(result)
        end
      end

      context 'when image has b64_json' do
        it 'uploads and returns URL' do
          allow(uploader).to receive(:upload).and_return('https://0x0.st/abc.png')
          result = { images: [{ b64_json: 'data', mime_type: 'image/png' }] }

          processed = processor.process(result)

          expect(processed[:images].first).to eq({ url: 'https://0x0.st/abc.png' })
        end
      end

      context 'when image has base64' do
        it 'uploads and returns URL' do
          allow(uploader).to receive(:upload).and_return('https://0x0.st/def.png')
          result = { images: [{ base64: 'data', mime_type: 'image/png' }] }

          processed = processor.process(result)

          expect(processed[:images].first).to eq({ url: 'https://0x0.st/def.png' })
        end
      end

      context 'when image has URL' do
        it 'returns unchanged' do
          result = { images: [{ url: 'https://example.com/img.png' }] }

          processed = processor.process(result)

          expect(processed[:images].first).to eq({ url: 'https://example.com/img.png' })
        end
      end

      context 'when upload fails' do
        it 'returns an error result with status code and body' do
          allow(uploader).to receive(:upload)
            .and_return(error: true, status_code: '500', body: 'Internal Server Error')
          result = { images: [{ b64_json: 'data', mime_type: 'image/png' }] }

          processed = processor.process(result)

          expect(processed).to eq(
            error: true,
            code: -32_603,
            message: 'Upload failed (HTTP 500): Internal Server Error'
          )
        end
      end

      context 'with string keys in result' do
        it 'handles string keys' do
          allow(uploader).to receive(:upload).and_return('https://0x0.st/test.png')
          result = { 'images' => [{ 'b64_json' => 'data', 'mime_type' => 'image/png' }] }

          processed = processor.process(result)

          expect(processed[:images].first).to eq({ url: 'https://0x0.st/test.png' })
        end
      end

      context 'with multiple images' do
        it 'processes each image' do
          call_count = 0
          allow(uploader).to receive(:upload) do
            call_count += 1
            "https://0x0.st/img#{call_count}.png"
          end

          result = {
            images: [
              { b64_json: 'data1', mime_type: 'image/png' },
              { url: 'https://existing.com/img.png' },
              { b64_json: 'data2', mime_type: 'image/jpeg' }
            ]
          }

          processed = processor.process(result)

          expect(processed[:images][0]).to eq({ url: 'https://0x0.st/img1.png' })
          expect(processed[:images][1]).to eq({ url: 'https://existing.com/img.png' })
          expect(processed[:images][2]).to eq({ url: 'https://0x0.st/img2.png' })
        end
      end

      context 'with multiple images when one fails' do
        it 'returns the error from the first failed upload' do
          call_count = 0
          allow(uploader).to receive(:upload) do
            call_count += 1
            if call_count == 1
              'https://0x0.st/img1.png'
            else
              { error: true, status_code: '413', body: 'File too large' }
            end
          end

          result = {
            images: [
              { b64_json: 'data1', mime_type: 'image/png' },
              { b64_json: 'data2', mime_type: 'image/jpeg' }
            ]
          }

          processed = processor.process(result)

          expect(processed).to eq(
            error: true,
            code: -32_603,
            message: 'Upload failed (HTTP 413): File too large'
          )
        end
      end

      context 'when image is not a hash' do
        it 'returns unchanged' do
          result = { images: ['not a hash'] }

          processed = processor.process(result)

          expect(processed[:images].first).to eq('not a hash')
        end
      end

      context 'when mime_type is missing' do
        it 'defaults to image/png' do
          allow(uploader).to receive(:upload).with('data', 'image/png').and_return('https://0x0.st/x.png')
          result = { images: [{ b64_json: 'data' }] }

          processor.process(result)

          expect(uploader).to have_received(:upload).with('data', 'image/png')
        end
      end
    end
  end
end
