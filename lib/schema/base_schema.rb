# frozen_string_literal: true

module Schema
  # Base class for schema builders
  class BaseSchema
    def build
      raise NotImplementedError
    end

    private

    def object_schema(properties, required = [])
      schema = { type: 'object', properties: properties }
      schema[:required] = required unless required.empty?
      schema
    end
  end
end
