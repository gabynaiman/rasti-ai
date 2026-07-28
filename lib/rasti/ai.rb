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
    require_relative 'ai/roles'
    require_relative 'ai/usage'
    require_relative 'ai/result'
    require_relative 'ai/assistant_state'
    require_relative 'ai/tool'
    require_relative 'ai/tool_serializer'
    require_relative 'ai/provider_aware'
    require_relative 'ai/client'
    require_relative 'ai/assistant'
    require_relative 'ai/provider'
    require_relative_pattern 'ai/open_ai/*'
    require_relative_pattern 'ai/**/*'

    attr_config :logger, Logger.new(STDOUT)

    attr_config :http_connect_timeout, 60
    attr_config :http_read_timeout, 60
    attr_config :http_max_retries, 3

    attr_config :default_provider, ENV['AI_DEFAULT_PROVIDER']

    attr_config :openai_api_key, ENV['OPENAI_API_KEY']
    attr_config :openai_default_model, ENV['OPENAI_DEFAULT_MODEL']

    attr_config :gemini_api_key, ENV['GEMINI_API_KEY']
    attr_config :gemini_default_model, ENV['GEMINI_DEFAULT_MODEL']

    attr_config :anthropic_api_key, ENV['ANTHROPIC_API_KEY']
    attr_config :anthropic_default_model, ENV['ANTHROPIC_DEFAULT_MODEL']

    attr_config :openrouter_api_key, ENV['OPENROUTER_API_KEY']
    attr_config :openrouter_default_model, ENV['OPENROUTER_DEFAULT_MODEL']

    attr_config :huawei_maas_api_key, ENV['HUAWEI_MAAS_API_KEY']
    attr_config :huawei_maas_default_model, ENV['HUAWEI_MAAS_DEFAULT_MODEL']

    attr_config :usage_tracker, nil

    class << self

      def provider(name=nil, model:nil, api_key:nil, usage_tracker:nil, logger:nil,
                        http_connect_timeout:nil, http_read_timeout:nil, http_max_retries:nil)

        build_provider(
          name, model, api_key, usage_tracker, logger,
          http_connect_timeout, http_read_timeout, http_max_retries
        ).first
      end

      def create_assistant(provider:nil, model:nil, api_key:nil, usage_tracker:nil, logger:nil,
                                http_connect_timeout:nil, http_read_timeout:nil, http_max_retries:nil,
                                state:nil, system:nil, tools:[], mcp_servers:{}, json_schema:nil,
                                thinking:nil, client:nil)

        resolved_provider, resolved_model = build_provider(
          provider, model, api_key, usage_tracker, logger,
          http_connect_timeout, http_read_timeout, http_max_retries
        )

        resolved_provider.create_assistant(
          model: resolved_model,
          state: state,
          system: system,
          tools: tools,
          mcp_servers: mcp_servers,
          json_schema: json_schema,
          thinking: thinking,
          client: client
        )
      end

      def generate_text(provider:nil, model:nil, api_key:nil, usage_tracker:nil, logger:nil,
                            http_connect_timeout:nil, http_read_timeout:nil, http_max_retries:nil,
                            prompt:nil, messages:nil, system:nil, json_schema:nil,
                            thinking:nil, client:nil)

        resolved_provider, resolved_model = build_provider(
          provider, model, api_key, usage_tracker, logger,
          http_connect_timeout, http_read_timeout, http_max_retries
        )

        resolved_provider.generate_text(
          model: resolved_model,
          prompt: prompt,
          messages: messages,
          system: system,
          json_schema: json_schema,
          thinking: thinking,
          client: client
        )
      end

      private

      def build_provider(name, model, api_key, usage_tracker, logger,
                         http_connect_timeout, http_read_timeout, http_max_retries)

        name, model = split_provider_and_model name, model

        resolved_provider = Provider.build name,
                                           model: model,
                                           api_key: api_key,
                                           usage_tracker: usage_tracker,
                                           logger: logger,
                                           http_connect_timeout: http_connect_timeout,
                                           http_read_timeout: http_read_timeout,
                                           http_max_retries: http_max_retries

        [resolved_provider, model]
      end

      def split_provider_and_model(name, model)
        if name.nil? && model.to_s.include?(':')
          name, model = model.split ':', 2
        end

        name ||= default_provider

        raise ArgumentError, "Undefined provider. Set it with provider: or Rasti::AI.default_provider. Valid providers: #{Provider.names.join(', ')}" if name.nil?

        [name, model]
      end

    end

  end
end
