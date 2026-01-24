# frozen_string_literal: true

require_relative 'provider_config'
require_relative 'schema/generate_image_schema'
require_relative 'schema/list_models_schema'
require_relative 'schema/list_providers_schema'

# Defines MCP tool schemas
class ToolsSchema
  def initialize(provider_config: ProviderConfig.new)
    @provider_config = provider_config
  end

  def all
    [generate_image_tool, list_models_tool, list_providers_tool]
  end

  private

  def generate_image_tool
    schema = build_generate_schema
    build_tool('generate_image', generate_description, schema)
  end

  def build_generate_schema
    Schema::GenerateImageSchema.new(provider_names).build
  end

  def list_models_tool
    schema = build_models_schema
    build_tool('list_models', models_description, schema)
  end

  def build_models_schema
    Schema::ListModelsSchema.new(provider_names).build
  end

  def list_providers_tool
    schema = Schema::ListProvidersSchema.new.build
    build_tool('list_providers', providers_description, schema)
  end

  def build_tool(name, description, input_schema)
    { name: name, description: description, inputSchema: input_schema }
  end

  def provider_names
    @provider_config.available_providers.map(&:to_s)
  end

  def generate_description
    'Generate images from a text prompt using AI image generation services'
  end

  def models_description
    'List available image generation models for a provider'
  end

  def providers_description
    'List all supported image generation providers'
  end
end
