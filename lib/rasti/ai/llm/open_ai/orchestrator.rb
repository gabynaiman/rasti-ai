module Rasti
  module AI
    module LLM
      module OpenAI
        class Orchestrator

          class ToolProxy < Rasti::Model[:executor, :serialization]
            def call(arguments)
              executor.call arguments
            end
          end

          def initialize(session:, logger:nil)
            @session = session
            @logger = logger || Rasti::AI.logger
          end

          def call(prompt)
            session.add_message Message.from_user(content: prompt)

            loop do
              response = client.chat_completions messages: session.all_messages.map(&:to_h),
                                                 model: session.configuration.llm.model,
                                                 tools: tools.values.map(&:serialization),
                                                 response_format: response_format

              choice = response['choices'][0]['message']

              if choice['tool_calls']
                session.add_message Message.from_assistant tool_calls: choice['tool_calls']

                choice['tool_calls'].each do |tool_call|
                  name = tool_call['function']['name']
                  arguments = JSON.parse tool_call['function']['arguments']

                  result = call_tool name, arguments

                  session.add_message Message.from_tool(tool_call_id: tool_call['id'], content: result)
                end
              else
                session.add_message Message.from_assistant(content: choice['content'])
                return choice['content']
              end
            end
          end

          private

          attr_reader :session, :logger

          def client
            @client ||= Client.new api_key: session.configuration.llm.api_key,
                                   logger: logger
          end

          def tools
            @tools ||= begin
              tools = {}

              session.configuration.tools.each do |tool|
                serialization = serialize_tool tool
                tools[serialization[:function][:name]] = ToolProxy.new executor: tool, 
                                                                       serialization: serialization 
              end

              session.configuration.mcp_servers.each do |name, mcp_config|
                mcp_client = MCP::Client.new url: mcp_config.url, 
                                             allowed_tools: mcp_config.allowed_tools,
                                             logger: logger
                                  
                mcp_client.list_tools.each do |tool|
                  mcp_tool_name = "#{name}_#{tool['name']}"

                  serialization = wrap_tool_serialization tool.merge('name' => mcp_tool_name)

                  executor = ->(args) do
                    mcp_client.call_tool tool['name'], args
                  end

                  tools[mcp_tool_name] = ToolProxy.new executor: executor, 
                                                       serialization: serialization 
                end
              end
              
              tools
            end
          end

          def call_tool(name, arguments)
            raise Errors::UndefinedTool.new(name) unless tools.key? name

            logger.info(self.class) { "Calling function #{name} with #{arguments}" }

            result = tools[name].call arguments

            logger.info(self.class) { "Function result: #{result}" }

            result

          rescue => ex
            logger.warn(self.class) { "Function failed: #{ex.message}\n#{ex.backtrace.join("\n")}" }
            "Error: #{ex.message}"
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

          def response_format
            return nil if session.configuration.output_schema.nil?

            {
              type: 'json_schema',
              json_schema: output_schema
            }
          end

        end
      end
    end
  end
end