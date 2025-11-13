module Rasti
  module AI
    module OpenAI
      class Assistant

        attr_reader :state

        def initialize(client:nil, json_schema:nil, state:nil, model:nil, tools:[], mcps:{}, logger:nil)
          @client = client || Client.new
          @json_schema = json_schema
          @state = state || AssistantState.new
          @model = model
          @tools = {}
          @serialized_tools = []
          @logger = logger || Rasti::AI.logger

          tools.each do |tool|
            serialization = serialize_tool tool
            @tools[serialization[:function][:name]] = tool
            @serialized_tools << serialization
          end

          mcps.each do |name, mcp|
            mcp.list_tools.each do |tool|
              serialization = wrap_tool_serialization tool.merge('name' => "#{name}_#{tool['name']}")
              @tools["#{name}_#{tool['name']}"] = ->(args) do
                mcp.call_tool tool['name'], args
              end
              @serialized_tools << serialization
            end
          end
        end

        def call(prompt)
          messages << {
            role: Roles::USER,
            content: prompt
          }

          loop do
            response = client.chat_completions messages: messages,
                                               model: model,
                                               tools: serialized_tools,
                                               response_format: response_format

            choice = response['choices'][0]['message']

            if choice['tool_calls']
              messages << {
                role: Roles::ASSISTANT,
                tool_calls: choice['tool_calls']
              }

              choice['tool_calls'].each do |tool_call|
                name = tool_call['function']['name']
                args = JSON.parse tool_call['function']['arguments']

                result = call_tool name, args

                messages << {
                  role: Roles::TOOL,
                  tool_call_id: tool_call['id'],
                  content: result
                }
              end
            else
              messages << {
                role: Roles::ASSISTANT,
                content: choice['content']
              }

              return choice['content']
            end
          end
        end

        private

        attr_reader :client, :json_schema, :model, :tools, :serialized_tools, :logger

        def messages
          state.messages
        end

        def serialize_tool(tool)
          serialization = ToolSerializer.serialize tool.class
          wrap_tool_serialization serialization
        end

        def wrap_tool_serialization(serialized_tool)
          {
            type: 'function',
            function: serialized_tool
          }
        end

        def call_tool(name, args)
          raise Errors::UndefinedTool.new(name) unless tools.key? name

          key = "#{name} -> #{args}"

          state.fetch(key) do
            logger.info(self.class) { "Calling function #{name} with #{args}" }

            result = tools[name].call args

            logger.info(self.class) { "Function result: #{result}" }

            result
          end

        rescue => ex
          logger.warn(self.class) { "Function failed: #{ex.message}\n#{ex.backtrace.join("\n")}" }
          "Error: #{ex.message}"
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