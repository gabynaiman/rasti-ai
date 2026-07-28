module Rasti
  module AI
    module Anthropic
      class Client < Rasti::AI::Client

        ANTHROPIC_VERSION = '2023-06-01'.freeze
        DEFAULT_MAX_TOKENS = 4096

        def messages(messages:, model:nil, system:nil, tools:[], tool_choice:nil, max_tokens:nil, thinking:nil)
          body = {
            model: model || default_model,
            max_tokens: max_tokens || DEFAULT_MAX_TOKENS,
            messages: messages
          }

          body[:thinking] = thinking if thinking
          body[:system] = system if system
          body[:tools] = tools unless tools.empty?
          body[:tool_choice] = tool_choice if tool_choice

          post '/messages', body
        end

        private

        def build_request(uri)
          request = super
          request['x-api-key'] = api_key
          request['anthropic-version'] = ANTHROPIC_VERSION
          request
        end

      end
    end
  end
end
