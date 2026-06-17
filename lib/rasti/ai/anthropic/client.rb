module Rasti
  module AI
    module Anthropic
      class Client < Rasti::AI::Client

        ANTHROPIC_VERSION = '2023-06-01'.freeze
        DEFAULT_MAX_TOKENS = 4096

        def messages(messages:, model:nil, system:nil, tools:[], tool_choice:nil, max_tokens:nil, thinking:nil)
          body = {
            model:      model || Rasti::AI.anthropic_default_model,
            max_tokens: max_tokens || DEFAULT_MAX_TOKENS,
            messages:   messages
          }

          body[:thinking]    = thinking    if thinking
          body[:system]      = system      if system
          body[:tools]       = tools       unless tools.empty?
          body[:tool_choice] = tool_choice if tool_choice

          post '/messages', body
        end

        private

        def parse_usage(response)
          usage = response['usage']
          return unless usage
          Usage.new(
            provider:          'anthropic',
            model:             response['model'],
            input_tokens:      usage['input_tokens'],
            output_tokens:     usage['output_tokens'],
            cached_tokens:     usage['cache_read_input_tokens'] || 0,
            reasoning_tokens:  0,
            raw:               usage
          )
        end

        def default_api_key
          Rasti::AI.anthropic_api_key
        end

        def base_url
          'https://api.anthropic.com/v1'
        end

        def build_request(uri)
          request = super
          request['x-api-key']        = api_key
          request['anthropic-version'] = ANTHROPIC_VERSION
          request
        end

      end
    end
  end
end
