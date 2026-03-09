module Rasti
  module AI
    class Assistant

      attr_reader :state

      def initialize(client:nil, json_schema:nil, state:nil, model:nil, tools:[], mcp_servers:{}, logger:nil, usage_tracker:nil)
        @client = client || build_default_client
        @json_schema = json_schema
        @state = state || AssistantState.new
        @model = model
        @tools = {}
        @serialized_tools = []
        @logger = logger || Rasti::AI.logger
        @usage_tracker = usage_tracker || Rasti::AI.usage_tracker

        register_tools(tools)
        register_mcp_servers(mcp_servers)
      end

      def call(prompt)
        messages << build_user_message(prompt)

        loop do
          response = request_completion
          track_usage response

          tool_calls = parse_tool_calls(response)

          if tool_calls.any?
            messages << build_assistant_tool_calls_message(response)

            tool_calls.each do |tool_call|
              name, args = extract_tool_call_info(tool_call)
              result = call_tool(name, args)
              messages << build_tool_result_message(tool_call, name, result)
            end
          else
            content = parse_content(response)

            messages << build_assistant_message(content)

            return content if finished?(response)
          end
        end
      end

      private

      attr_reader :client, :json_schema, :model, :tools, :serialized_tools, :logger, :usage_tracker

      def messages
        state.messages
      end

      def track_usage(response)
        return unless usage_tracker
        usage = parse_usage response
        usage_tracker.call usage if usage
      end

      # --- Shared behavior ---

      def register_tools(tools)
        tools.each do |tool|
          serialization = wrap_tool_serialization(ToolSerializer.serialize(tool.class))
          name = extract_tool_name(serialization)
          @tools[name] = tool
          @serialized_tools << serialization
        end
      end

      def register_mcp_servers(mcp_servers)
        mcp_servers.each do |server_name, mcp|
          mcp.list_tools.each do |tool|
            prefixed_name = "#{server_name}_#{tool['name']}"
            raw = tool.merge('name' => prefixed_name)
            serialization = wrap_tool_serialization(raw)
            @tools[prefixed_name] = ->(args) { mcp.call_tool tool['name'], args }
            @serialized_tools << serialization
          end
        end
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

      # --- Template methods ---

      def build_default_client
        raise NotImplementedError
      end

      def build_user_message(prompt)
        raise NotImplementedError
      end

      def build_assistant_message(content)
        raise NotImplementedError
      end

      def build_assistant_tool_calls_message(response)
        raise NotImplementedError
      end

      def build_tool_result_message(tool_call, name, result)
        raise NotImplementedError
      end

      def request_completion
        raise NotImplementedError
      end

      def parse_tool_calls(response)
        raise NotImplementedError
      end

      def parse_content(response)
        raise NotImplementedError
      end

      def finished?(response)
        raise NotImplementedError
      end

      def parse_usage(response)
        raise NotImplementedError
      end

      def extract_tool_call_info(tool_call)
        raise NotImplementedError
      end

      def wrap_tool_serialization(raw)
        raise NotImplementedError
      end

      def extract_tool_name(wrapped)
        raise NotImplementedError
      end

    end
  end
end
