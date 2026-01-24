# frozen_string_literal: true

require_relative 'base_schema'

module Schema
  # Schema for list_providers tool
  class ListProvidersSchema < BaseSchema
    def build
      { type: 'object', properties: {} }
    end
  end
end
