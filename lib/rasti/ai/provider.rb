module Rasti
  module AI
    class Provider

      MODULES = {
        open_ai: 'OpenAI',
        gemini: 'Gemini',
        anthropic: 'Anthropic',
        open_router: 'OpenRouter',
        huawei_maas: 'HuaweiMaaS'
      }.freeze

      ALIASES = {
        openai: :open_ai,
        openrouter: :open_router,
        huawei: :huawei_maas
      }.freeze

      class << self

        def build(name, **options)
          return name if name.is_a? Provider
          provider_class(name).new(**options)
        end

        def names
          MODULES.keys
        end

        private

        def provider_class(name)
          key = normalize name
          key = ALIASES.fetch key, key

          raise Errors::UnknownProvider.new(name, names) unless MODULES.key? key

          AI.const_get(MODULES[key])::Provider
        end

        def normalize(name)
          name.to_s.downcase.to_sym
        end

      end

      attr_reader :model

      def initialize(model:nil, api_key:nil, usage_tracker:nil, logger:nil,
                     http_connect_timeout:nil, http_read_timeout:nil, http_max_retries:nil)

        @model = model || default_model
        @api_key = api_key || default_api_key
        @usage_tracker = usage_tracker
        @logger = logger
        @http_connect_timeout = http_connect_timeout
        @http_read_timeout = http_read_timeout
        @http_max_retries = http_max_retries
      end

      def name
        raise NotImplementedError
      end

      def default_model
        raise NotImplementedError
      end

      def default_api_key
        raise NotImplementedError
      end

      def base_url
        raise NotImplementedError
      end

      def parse_usage(response)
        raise NotImplementedError
      end

      def build_client
        client_class.new(
          provider: self,
          api_key: api_key,
          logger: logger,
          usage_tracker: usage_tracker,
          http_connect_timeout: http_connect_timeout,
          http_read_timeout: http_read_timeout,
          http_max_retries: http_max_retries
        )
      end

      def create_assistant(state:nil, system:nil, model:nil, tools:[], mcp_servers:{},
                           json_schema:nil, thinking:nil, client:nil)

        raise ArgumentError, 'Use state or system, not both' if state && system

        state = AssistantState.new(context: system) if state.nil? && system

        assistant_class.new(
          provider: self,
          client: client,
          model: model || self.model,
          state: state,
          tools: tools,
          mcp_servers: mcp_servers,
          json_schema: json_schema,
          thinking: thinking,
          logger: logger
        )
      end

      def generate_text(prompt:nil, messages:nil, system:nil, model:nil,
                        json_schema:nil, thinking:nil, client:nil)

        raise ArgumentError, 'Use prompt or messages, not both' if prompt && messages
        raise ArgumentError, 'Undefined prompt or messages' if prompt.nil? && messages.nil?

        system_prompt, conversation = split_system(messages || [{role: Roles::USER, content: prompt}])

        client ||= build_client

        response = request(
          client: client,
          messages: conversation.map { |message| encode_message message },
          system: system || system_prompt,
          model: model || self.model,
          json_schema: json_schema,
          thinking: thinking_config(thinking)
        )

        Result.new content: parse_content(response),
                   usage: parse_usage(response),
                   raw: response
      end

      private

      attr_reader :api_key, :usage_tracker, :logger,
                  :http_connect_timeout, :http_read_timeout, :http_max_retries

      def provider_module
        AI.const_get MODULES.fetch(name)
      end

      def client_class
        provider_module::Client
      end

      def assistant_class
        provider_module::Assistant
      end

      def split_system(messages)
        normalized = messages.map { |message| normalize_message message }

        system_messages, conversation = normalized.partition { |message| message[:role] == Roles::SYSTEM }

        system_prompt = system_messages.map { |message| message[:content] }.join("\n") unless system_messages.empty?

        [system_prompt, conversation]
      end

      def normalize_message(message)
        {
          role: (message[:role] || message['role'] || Roles::USER).to_s,
          content: message[:content] || message['content']
        }
      end

      def thinking_config(level)
        return nil if level.nil?

        levels = self.class::THINKING_LEVELS

        raise ArgumentError, "Invalid thinking level '#{level}'. Valid: #{levels.keys.join(', ')}" unless levels.key? level

        levels[level]
      end

      # --- Template methods ---

      def request(client:, messages:, system:, model:, json_schema:, thinking:)
        raise NotImplementedError
      end

      def encode_message(message)
        raise NotImplementedError
      end

      def parse_content(response)
        raise NotImplementedError
      end

    end
  end
end
