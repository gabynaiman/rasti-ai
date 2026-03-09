module Rasti
  module AI
    module OpenAI
      class Assistant < Rasti::AI::Assistant

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
          choice = response['choices'][0]['message']
          {role: Roles::ASSISTANT, tool_calls: choice['tool_calls']}
        end

        def build_tool_result_message(tool_call, name, result)
          {role: Roles::TOOL, tool_call_id: tool_call['id'], content: result}
        end

        def request_completion
          msgs = if state.context
            [{role: Roles::SYSTEM, content: state.context}] + messages
          else
            messages
          end

          client.chat_completions messages: msgs,
                                  model: model,
                                  tools: serialized_tools,
                                  response_format: response_format
        end

        def parse_tool_calls(response)
          response.dig('choices', 0, 'message', 'tool_calls') || []
        end

        def parse_content(response)
          response.dig('choices', 0, 'message', 'content')
        end

        def finished?(response)
          response.dig('choices', 0, 'finish_reason') == 'stop'
        end

        def extract_tool_call_info(tool_call)
          name = tool_call['function']['name']
          args = JSON.parse(tool_call['function']['arguments'])
          [name, args]
        end

        def wrap_tool_serialization(raw)
          {type: 'function', function: raw}
        end

        def extract_tool_name(wrapped)
          wrapped[:function][:name] || wrapped[:function]['name']
        end

        def response_format
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