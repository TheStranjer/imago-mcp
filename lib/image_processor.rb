# frozen_string_literal: true

require_relative 'image_uploader'
require_relative 'upload_config'

# Processes generated images and optionally uploads them
class ImageProcessor
  def initialize(config: UploadConfig.new, uploader: nil)
    @config = config
    @uploader = uploader || ImageUploader.new(config: config)
  end

  def process(result)
    validate_and_process(result, extract_images(result))
  end

  private

  def validate_and_process(result, images)
    return empty_images_error if empty_images?(images)
    return result unless uploadable?(images)

    process_images(result, images)
  end

  def extract_images(result)
    result[:images] || result['images']
  end

  def empty_images?(images)
    images.is_a?(Array) && images.empty?
  end

  def uploadable?(images)
    @config.enabled? && images.is_a?(Array)
  end

  def process_images(result, images)
    processed = images.map { |img| process_image(img) }
    first_failure(processed) || build_result(result, processed)
  end

  def first_failure(processed)
    processed.find { |img| upload_error?(img) }
  end

  def process_image(image)
    return image unless image.is_a?(Hash)

    normalized = normalize_keys(image)
    upload_if_base64(normalized)
  end

  def normalize_keys(image)
    image.transform_keys(&:to_sym)
  end

  def upload_if_base64(image)
    base64_data = image[:b64_json] || image[:base64]
    return image unless base64_data

    upload_image(base64_data, image)
  end

  def upload_image(base64_data, image)
    mime = image[:mime_type] || 'image/png'
    result = @uploader.upload(base64_data, mime)
    return upload_error_result(result) if upload_error?(result)

    { url: result }
  end

  def upload_error?(result)
    result.is_a?(Hash) && result[:error]
  end

  def empty_images_error
    {
      error: true,
      code: -32_602,
      message: 'Image generation produced no images. Verify the model supports image generation using list_models.'
    }
  end

  def upload_error_result(result)
    {
      error: true,
      code: -32_603,
      message: "Upload failed (HTTP #{result[:status_code]}): #{result[:body]}"
    }
  end

  def build_result(result, processed)
    sym_result = result.transform_keys(&:to_sym)
    sym_result[:images] = processed
    sym_result
  end
end
