# frozen_string_literal: true

require_relative 'base_schema'
require_relative 'image_input_schema'

module Schema
  # Schema for generate_image tool
  class GenerateImageSchema < BaseSchema
    def initialize(provider_names)
      super()
      @provider_names = provider_names
    end

    def build
      object_schema(all_properties, %w[provider prompt])
    end

    private

    def all_properties
      basic_properties.merge(format_properties).merge(image_properties)
    end

    def basic_properties
      {
        provider: provider_property,
        prompt: prompt_property,
        model: model_property,
        n: n_property
      }
    end

    def format_properties
      {
        size: size_property,
        quality: quality_property,
        aspect_ratio: aspect_ratio_property,
        negative_prompt: negative_prompt_property
      }
    end

    def image_properties
      {
        seed: seed_property,
        response_format: response_format_property,
        images: images_property
      }
    end

    def provider_property
      {
        type: 'string',
        enum: @provider_names,
        description: 'The AI provider to use (openai, gemini, or xai)'
      }
    end

    def prompt_property
      string_property('The text prompt describing the image to generate')
    end

    def model_property
      string_property('Specific model to use (optional, uses provider default if omitted)')
    end

    def n_property
      {
        type: 'integer',
        description: 'Number of images to generate (default: 1)',
        minimum: 1,
        maximum: 10
      }
    end

    def size_property
      string_property('Image size (OpenAI only): 256x256, 512x512, 1024x1024, 1792x1024, 1024x1792')
    end

    def quality_property
      enum_property(%w[standard hd], 'Image quality (OpenAI only): standard or hd')
    end

    def aspect_ratio_property
      string_property('Aspect ratio (Gemini only): e.g., 16:9, 4:3, 1:1')
    end

    def negative_prompt_property
      string_property('Terms to exclude from generation (Gemini only)')
    end

    def seed_property
      { type: 'integer', description: 'Seed for reproducibility (Gemini only)' }
    end

    def response_format_property
      enum_property(%w[url b64_json], 'Response format (OpenAI/xAI): url or b64_json')
    end

    def images_property
      ImageInputSchema.new.build
    end

    def string_property(description)
      { type: 'string', description: description }
    end

    def enum_property(values, description)
      { type: 'string', enum: values, description: description }
    end
  end
end
