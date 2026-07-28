module Rasti
  module AI
    module Anthropic
      class Provider < Rasti::AI::Provider

        STRUCTURED_OUTPUT_TOOL = 'structured_output'.freeze

        THINKING_LEVELS = {
          'low' => {type: 'enabled', budget_tokens: 1_024}.freeze,
          'medium' => {type: 'enabled', budget_tokens: 8_000}.freeze,
          'high' => {type: 'enabled', budget_tokens: 16_000}.freeze
        }.freeze

        def name
          :anthropic
        end

        def default_model
          Rasti::AI.anthropic_default_model
        end

        def default_api_key
          Rasti::AI.anthropic_api_key
        end

        def base_url
          'https://api.anthropic.com/v1'
        end

        def parse_usage(response)
          usage = response['usage']
          return nil unless usage

          Usage.new(
            provider: name.to_s,
            model: response['model'],
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cached_tokens: usage['cache_read_input_tokens'] || 0,
            reasoning_tokens: 0,
            raw: usage
          )
        end

        private

        def request(client:, messages:, system:, model:, json_schema:, thinking:)
          tools = json_schema ? [structured_output_tool(json_schema)] : []
          tool_choice = json_schema ? {type: 'tool', name: STRUCTURED_OUTPUT_TOOL} : nil

          client.messages messages: messages,
                          model: model,
                          system: system,
                          tools: tools,
                          tool_choice: tool_choice,
                          thinking: thinking
        end

        def encode_message(message)
          {role: message[:role], content: message[:content]}
        end

        def parse_content(response)
          content = response['content'] || []

          structured = content.find { |block| block['type'] == 'tool_use' && block['name'] == STRUCTURED_OUTPUT_TOOL }
          return JSON.dump(structured['input']) if structured

          text_block = content.find { |block| block['type'] == 'text' }
          text_block['text'] if text_block
        end

        def structured_output_tool(json_schema)
          {
            name: STRUCTURED_OUTPUT_TOOL,
            description: 'Return the structured response',
            input_schema: {
              type: 'object',
              properties: json_schema
            }
          }
        end

      end
    end
  end
end
