module Rasti
  module AI
    module OpenAI
      class Provider < Rasti::AI::Provider

        THINKING_LEVELS = {
          'none' => 'none'.freeze,
          'low' => 'low'.freeze,
          'medium' => 'medium'.freeze,
          'high' => 'high'.freeze
        }.freeze

        def name
          :open_ai
        end

        def default_model
          Rasti::AI.openai_default_model
        end

        def default_api_key
          Rasti::AI.openai_api_key
        end

        def base_url
          'https://api.openai.com/v1'
        end

        def parse_usage(response)
          usage = response['usage']
          return nil unless usage

          Usage.new(
            provider: name.to_s,
            model: response['model'],
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            cached_tokens: usage.dig('prompt_tokens_details', 'cached_tokens') || 0,
            reasoning_tokens: usage.dig('completion_tokens_details', 'reasoning_tokens') || 0,
            raw: usage
          )
        end

        private

        def request(client:, messages:, system:, model:, json_schema:, thinking:)
          all_messages = system ? [{role: Roles::SYSTEM, content: system}] + messages : messages

          client.chat_completions messages: all_messages,
                                  model: model,
                                  response_format: response_format(json_schema),
                                  reasoning_effort: thinking
        end

        def encode_message(message)
          {role: message[:role], content: message[:content]}
        end

        def parse_content(response)
          response.dig 'choices', 0, 'message', 'content'
        end

        def response_format(json_schema)
          return nil if json_schema.nil?

          {
            type: 'json_schema',
            json_schema: json_schema
          }
        end

      end
    end
  end
end
