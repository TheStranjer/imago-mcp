# frozen_string_literal: true

require 'imago'
require_relative 'provider_config'
require_relative 'generate_options'
require_relative 'image_processor'

# Handles MCP tool calls
class ToolHandlers
  def initialize(provider_config: ProviderConfig.new, image_processor: nil)
    @provider_config = provider_config
    @image_processor = image_processor || ImageProcessor.new
  end

  def generate_image(arguments)
    client = build_client(arguments)
    result = execute_generation(client, arguments)
    @image_processor.process(result)
  end

  def list_models(arguments)
    provider = extract_provider(arguments)
    client = create_client(provider, nil)
    build_models_result(provider, client)
  end

  def list_providers
    providers = @provider_config.available_providers
    { providers: providers.map(&:to_s) }
  end

  private

  def build_client(arguments)
    provider = extract_provider(arguments)
    model = arguments['model']
    create_client(provider, model)
  end

  def extract_provider(arguments)
    arguments['provider'].to_sym
  end

  def execute_generation(client, arguments)
    prompt = arguments['prompt']
    options = GenerateOptions.new(arguments).build
    client.generate(prompt, options)
  end

  def create_client(provider, model)
    Imago.new(provider: provider, model: model)
  end

  def build_models_result(provider, client)
    { provider: provider.to_s, models: client.models }
  end
end
