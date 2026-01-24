# frozen_string_literal: true

require_relative 'base_schema'

module Schema
  # Schema for image input array
  class ImageInputSchema < BaseSchema
    def build
      {
        type: 'array',
        description: images_description,
        items: { oneOf: image_item_schemas }
      }
    end

    private

    def images_description
      'Input images for image editing (OpenAI/Gemini only). Each item can be: ' \
        '(1) a URL string, (2) an object with "url" and "mime_type", or ' \
        '(3) an object with "base64" and "mime_type"'
    end

    def image_item_schemas
      [url_string_schema, url_object_schema, base64_object_schema]
    end

    def url_string_schema
      string_schema('URL of the image (MIME type auto-detected from extension)')
    end

    def url_object_schema
      props = { url: url_property, mime_type: mime_type_property }
      object_schema(props, %w[url mime_type])
    end

    def base64_object_schema
      props = { base64: base64_property, mime_type: mime_type_property }
      object_schema(props, %w[base64 mime_type])
    end

    def string_schema(description)
      { type: 'string', description: description }
    end

    def url_property
      string_schema('URL of the image')
    end

    def base64_property
      string_schema('Base64-encoded image data')
    end

    def mime_type_property
      string_schema('MIME type (e.g., image/png, image/jpeg)')
    end
  end
end
