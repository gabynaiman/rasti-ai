module Rasti
  module AI
    module OpenAI
      class Client < Rasti::AI::Client

        def chat_completions(messages:, model:nil, tools:[], response_format:nil, reasoning_effort:nil)
          body = {
            model: model || default_model,
            messages: messages,
            tools: tools,
            tool_choice: tools.empty? ? 'none' : 'auto'
          }

          body[:response_format] = response_format if response_format
          body[:reasoning_effort] = reasoning_effort if reasoning_effort

          post '/chat/completions', body
        end

        private

        def build_request(uri)
          request = super
          request['Authorization'] = "Bearer #{api_key}"
          request
        end

      end
    end
  end
end
