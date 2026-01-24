# frozen_string_literal: true

require_relative 'base_schema'

module Schema
  # Schema for list_models tool
  class ListModelsSchema < BaseSchema
    def initialize(provider_names)
      super()
      @provider_names = provider_names
    end

    def build
      object_schema({ provider: provider_property }, ['provider'])
    end

    private

    def provider_property
      {
        type: 'string',
        enum: @provider_names,
        description: 'The AI provider to query (openai, gemini, or xai)'
      }
    end
  end
end
