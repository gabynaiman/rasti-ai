require 'multi_require'
require 'rasti-form'
require 'rasti-model'
require 'class_config'
require 'inflecto'
require 'net/http'
require 'uri'
require 'json'
require 'logger'

module Rasti
  module AI

    extend MultiRequire
    extend ClassConfig

    require_relative 'ai/errors'
    require_relative 'ai/usage'
    require_relative 'ai/assistant_state'
    require_relative 'ai/tool'
    require_relative 'ai/tool_serializer'
    require_relative 'ai/client'
    require_relative 'ai/assistant'
    require_relative_pattern 'ai/**/*'

    attr_config :logger, Logger.new(STDOUT)

    attr_config :http_connect_timeout, 60
    attr_config :http_read_timeout, 60
    attr_config :http_max_retries, 3

    attr_config :openai_api_key, ENV['OPENAI_API_KEY']
    attr_config :openai_default_model, ENV['OPENAI_DEFAULT_MODEL']

    attr_config :gemini_api_key, ENV['GEMINI_API_KEY']
    attr_config :gemini_default_model, ENV['GEMINI_DEFAULT_MODEL']

    attr_config :anthropic_api_key, ENV['ANTHROPIC_API_KEY']
    attr_config :anthropic_default_model, ENV['ANTHROPIC_DEFAULT_MODEL']

    attr_config :usage_tracker, nil

  end
end