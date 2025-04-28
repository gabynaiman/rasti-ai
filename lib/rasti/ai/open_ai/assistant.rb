module Rasti
  module AI
    module OpenAI
      class Assistant

        attr_reader :state

        def initialize(client:nil, state:nil, model:nil, tools:[], logger:nil)
          @client = client || Client.new
          @state = state || AssistantState.new
          @model = model
          @tools = {}
          @serialized_tools = []
          @logger = logger || Rasti::AI.logger

          tools.each do |tool|
            serialization = ToolSerializer.serialize tool.class
            @tools[serialization[:function][:name]] = tool
            @serialized_tools << serialization
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
                                               tools: serialized_tools

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

        attr_reader :client, :model, :tools, :serialized_tools, :logger

        def messages
          state.messages
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

      end
    end
  end
end