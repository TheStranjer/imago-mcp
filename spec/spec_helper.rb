# frozen_string_literal: true

require 'stringio'
require_relative '../imago_mcp_server'
require_relative 'support/request_helper'

RSpec.configure do |config|
  # Capture stdout/stderr to prevent cluttering terminal output
  config.around(:each) do |example|
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new

    begin
      example.run
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed

  config.include RequestHelper
end
