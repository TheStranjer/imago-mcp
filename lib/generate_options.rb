# frozen_string_literal: true

# Builds options hash for image generation
class GenerateOptions
  OPTION_KEYS = %w[n size quality aspect_ratio negative_prompt seed response_format].freeze

  def initialize(arguments)
    @arguments = arguments
  end

  def build
    options = extract_basic_options
    append_images(options)
    options
  end

  private

  def extract_basic_options
    options = {}
    OPTION_KEYS.each { |key| add_option(options, key) }
    options
  end

  def add_option(options, key)
    value = @arguments[key]
    options[key.to_sym] = value unless value.nil?
  end

  def append_images(options)
    return unless images?

    options[:images] = normalize_images
  end

  def images?
    images = @arguments['images']
    images && !images.empty?
  end

  def normalize_images
    @arguments['images'].map { |img| normalize_image(img) }
  end

  def normalize_image(image)
    return image if image.is_a?(String)

    image.transform_keys(&:to_sym)
  end
end
