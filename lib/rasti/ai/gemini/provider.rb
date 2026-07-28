module Rasti
  module AI
    module Gemini
      class Provider < Rasti::AI::Provider

        THINKING_LEVELS = {
          'low' => {thinking_budget: 1_024}.freeze,
          'medium' => {thinking_budget: 8_192}.freeze,
          'high' => {thinking_budget: 24_576}.freeze
        }.freeze

        def name
          :gemini
        end

        def default_model
          Rasti::AI.gemini_default_model
        end

        def default_api_key
          Rasti::AI.gemini_api_key
        end

        def base_url
          'https://generativelanguage.googleapis.com/v1beta'
        end

        def parse_usage(response)
          usage = response['usageMetadata']
          return nil unless usage

          Usage.new(
            provider: name.to_s,
            model: response['modelVersion'],
            input_tokens: usage['promptTokenCount'],
            output_tokens: usage['candidatesTokenCount'],
            cached_tokens: usage['cachedContentTokenCount'] || 0,
            reasoning_tokens: usage['thoughtsTokenCount'] || 0,
            raw: usage
          )
        end

        private

        def request(client:, messages:, system:, model:, json_schema:, thinking:)
          client.generate_content contents: messages,
                                  model: model,
                                  system_instruction: system_instruction(system),
                                  generation_config: generation_config(json_schema, thinking)
        end

        def encode_message(message)
          {
            role: encode_role(message[:role]),
            parts: [{text: message[:content]}]
          }
        end

        def encode_role(role)
          role == Rasti::AI::Roles::ASSISTANT ? Roles::MODEL : Roles::USER
        end

        def parse_content(response)
          parts = response.dig('candidates', 0, 'content', 'parts') || []
          text_part = parts.find { |part| part.key? 'text' }
          text_part['text'] if text_part
        end

        def system_instruction(system)
          return nil if system.nil?
          {parts: [{text: system}]}
        end

        def generation_config(json_schema, thinking)
          config = {}

          config[:thinking_config] = thinking if thinking

          if json_schema
            config[:response_mime_type] = 'application/json'
            config[:response_schema] = json_schema
          end

          config.empty? ? nil : config
        end

      end
    end
  end
end
