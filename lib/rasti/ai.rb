require 'multi_require'
require 'rasti-form'
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

    require_relative_pattern 'ai/**/*'

    attr_config :logger, Logger.new(STDOUT)

    attr_config :openai_api_key, ENV['OPENAI_API_KEY']
    attr_config :openai_default_model, ENV['OPENAI_DEFAULT_MODEL']

  end
end