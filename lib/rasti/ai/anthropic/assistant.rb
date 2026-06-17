module Rasti
  module AI
    module Anthropic
      class Assistant < Rasti::AI::Assistant

        ALLOWED_SCHEMA_FIELDS = %w[type description properties required enum items format nullable anyOf].freeze

        THINKING_LEVELS = {
          'low'    => {type: 'enabled', budget_tokens: 1_024}.freeze,
          'medium' => {type: 'enabled', budget_tokens: 8_000}.freeze,
          'high'   => {type: 'enabled', budget_tokens: 16_000}.freeze
        }.freeze

        private

        def build_default_client
          Client.new
        end

        def build_user_message(prompt)
          {role: Roles::USER, content: prompt}
        end

        def build_assistant_message(content)
          {role: Roles::ASSISTANT, content: content}
        end

        def build_assistant_tool_calls_message(response)
          {role: Roles::ASSISTANT, content: response['content']}
        end

        def build_tool_result_message(tool_call, name, result)
          {
            role:    Roles::USER,
            content: [{
              type:        'tool_result',
              tool_use_id: tool_call['id'],
              content:     result
            }]
          }
        end

        def request_completion
          all_tools = serialized_tools.dup
          all_tools << structured_output_tool if json_schema

          tc = if json_schema
            {type: 'tool', name: 'structured_output'}
          elsif all_tools.any?
            {type: 'auto'}
          end

          client.messages(
            messages:    messages,
            model:       model,
            system:      state.context,
            tools:       all_tools,
            tool_choice: tc,
            thinking:    thinking_config
          )
        end

        def thinking_config
          THINKING_LEVELS[thinking]
        end

        def parse_tool_calls(response)
          content = response['content'] || []
          content.select { |block| block['type'] == 'tool_use' && block['name'] != 'structured_output' }
        end

        def parse_content(response)
          content = response['content'] || []

          if json_schema
            structured = content.find { |block| block['type'] == 'tool_use' && block['name'] == 'structured_output' }
            return JSON.dump(structured['input']) if structured
          end

          text_block = content.find { |block| block['type'] == 'text' }
          text_block&.[]('text')
        end

        def finished?(response)
          !response['stop_reason'].nil?
        end

        def extract_tool_call_info(tool_call)
          [tool_call['name'], tool_call['input'] || {}]
        end

        def wrap_tool_serialization(raw)
          schema = raw[:inputSchema] || raw['inputSchema']

          result = {
            name:        raw[:name]        || raw['name'],
            description: raw[:description] || raw['description'] || raw[:title] || raw['title']
          }
          result[:input_schema] = sanitize_schema(schema) if schema
          result.reject { |_, v| v.nil? }
        end

        def sanitize_schema(schema)
          return schema unless schema.is_a?(Hash)

          schema.each_with_object({}) do |(key, value), acc|
            next unless ALLOWED_SCHEMA_FIELDS.include?(key.to_s)
            acc[key] = case key.to_s
                       when 'properties'
                         value.each_with_object({}) { |(k, v), h| h[k] = sanitize_schema(v) }
                       when 'items'
                         sanitize_schema(value)
                       when 'anyOf'
                         value.map { |item| sanitize_schema(item) }
                       else
                         value
                       end
          end
        end

        def extract_tool_name(wrapped)
          wrapped[:name] || wrapped['name']
        end

        def structured_output_tool
          {
            name:         'structured_output',
            description:  'Return the structured response',
            input_schema: {
              type:       'object',
              properties: json_schema
            }
          }
        end

      end
    end
  end
end
