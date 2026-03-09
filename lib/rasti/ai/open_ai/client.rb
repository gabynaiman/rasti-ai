module Rasti
  module AI
    module OpenAI
      class Client < Rasti::AI::Client

        def chat_completions(messages:, model:nil, tools:[], response_format:nil)
          body = {
            model: model || Rasti::AI.openai_default_model,
            messages: messages,
            tools: tools,
            tool_choice: tools.empty? ? 'none' : 'auto'
          }

          body[:response_format] = response_format unless response_format.nil?

          post '/chat/completions', body
        end

        private

        def default_api_key
          Rasti::AI.openai_api_key
        end

        def base_url
          'https://api.openai.com/v1'
        end

        def build_request(uri)
          request = super
          request['Authorization'] = "Bearer #{api_key}"
          request
        end

      end
    end
  end
end