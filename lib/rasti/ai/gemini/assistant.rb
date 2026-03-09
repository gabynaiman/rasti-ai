module Rasti
  module AI
    module Gemini
      class Assistant < Rasti::AI::Assistant

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

        def extract_tool_call_info(tool_call)
          fc = tool_call['functionCall']
          [fc['name'], fc['args'] || {}]
        end

        def wrap_tool_serialization(raw)
          result = raw.dup
          if result.key?(:inputSchema)
            result[:parameters] = result.delete(:inputSchema)
          elsif result.key?('inputSchema')
            result['parameters'] = result.delete('inputSchema')
          end
          result
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
