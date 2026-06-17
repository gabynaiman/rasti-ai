module Rasti
  module AI
    module Gemini
      class Assistant < Rasti::AI::Assistant

        ALLOWED_SCHEMA_FIELDS = %w[type description properties required enum items format nullable anyOf].freeze

        private

        def build_default_client
          Client.new
        end

        def build_user_message(prompt)
          {role: Roles::USER, parts: [{text: prompt}]}
        end

        def build_assistant_message(content)
          {role: Roles::MODEL, parts: [{text: content}]}
        end

        def build_assistant_tool_calls_message(response)
          response['candidates'][0]['content']
        end

        def build_tool_result_message(tool_call, name, result)
          {
            role: Roles::FUNCTION,
            parts: [{
              functionResponse: {
                name: name,
                response: {content: result}
              }
            }]
          }
        end

        def request_completion
          system_inst = if state.context
            {parts: [{text: state.context}]}
          end

          client.generate_content contents: messages,
                                  model: model,
                                  tools: serialized_tools_payload,
                                  system_instruction: system_inst,
                                  generation_config: generation_config
        end

        def parse_tool_calls(response)
          parts = response.dig('candidates', 0, 'content', 'parts') || []
          parts.select { |p| p.key?('functionCall') }
        end

        def parse_content(response)
          parts = response.dig('candidates', 0, 'content', 'parts') || []
          text_part = parts.find { |p| p.key?('text') }
          text_part['text']
        end

        def finished?(response)
          !response.dig('candidates', 0, 'finishReason').nil?
        end

        def extract_tool_call_info(tool_call)
          fc = tool_call['functionCall']
          [fc['name'], fc['args'] || {}]
        end

        def wrap_tool_serialization(raw)
          schema = raw[:inputSchema] || raw['inputSchema']

          result = {
            name:        raw[:name]        || raw['name'],
            description: raw[:description] || raw['description'] || raw[:title] || raw['title']
          }
          result[:parameters] = sanitize_schema(schema) if schema
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

        def serialized_tools_payload
          return [] if serialized_tools.empty?
          [{function_declarations: serialized_tools}]
        end

        def generation_config
          return nil if json_schema.nil?

          {
            response_mime_type: 'application/json',
            response_schema: json_schema
          }
        end

      end
    end
  end
end
