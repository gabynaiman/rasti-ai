module Rasti
  module AI
    module MCP
      class Server

        ToolSpecification = Rasti::Model[:tool, :serialization]

        PROTOCOL_VERSION = '2024-11-05'.freeze
        JSON_RPC_VERSION = '2.0'.freeze

        extend ClassConfig

        attr_config :server_name, 'MCP Server'
        attr_config :server_version, '1.0.0'
        attr_config :relative_path, '/mcp'
        
        class << self

          def register_tool(tool)
            serialization = ToolSerializer.serialize tool.class
            raise "Tool #{serialization[:name]} already exist" if tools.key? serialization[:name]
            tools[serialization[:name]] = ToolSpecification.new tool: tool, serialization: serialization
          end

          def clear_tools
            tools.clear
          end

          def tools_serializations
            tools.values.map(&:serialization)
          end

          def call_tool(name, arguments={})
            raise "Tool #{name} not found" unless tools.key? name
            tools[name].tool.call arguments
          end

          private

          def tools
            @tools ||= {}
          end

        end

        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new env
          
          if request.post? && request.path == self.class.relative_path
            handle_mcp_request request
          else
            app.call env
          end
        end

        private

        attr_reader :app

        def handle_mcp_request(request)
          body = request.body.read
          data = JSON.parse body
          
          response = case data['method']
          when 'initialize'
            handle_initialize data
          when 'tools/list'
            handle_tools_list data
          when 'tools/call'
            handle_tool_call data
          else
            error_response data['id'], JSON_RPC_METHOD_NOT_FOUND, 'Method not found'
          end
          
          [200, {'Content-Type' => 'application/json'}, [JSON.dump(response)]]

        rescue JSON::ParserError => e
          response = error_response nil, JSON_RPC_PARSE_ERROR, e.message
          [400, {'Content-Type' => 'application/json'}, [JSON.dump(response)]]
          
        rescue => e
          response = error_response nil, JSON_RPC_INTERNAL_ERROR, e.message
          [500, {'Content-Type' => 'application/json'}, [JSON.dump(response)]]
        end
        
        def handle_initialize(data)
          {
            jsonrpc: JSON_RPC_VERSION,
            id: data['id'],
            result: {
              protocolVersion: PROTOCOL_VERSION,
              capabilities: {
                tools: {
                  list: true,
                  call: true
                }
              },
              serverInfo: {
                name: self.class.server_name,
                version: self.class.server_version
              }
            }
          }
        end
        
        def handle_tools_list(data)
          {
            jsonrpc: JSON_RPC_VERSION,
            id: data['id'],
            result: {
              tools: self.class.tools_serializations
            }
          }
        end
        
        def handle_tool_call(data)
          tool_name = data['params']['name']
          arguments = data['params']['arguments'] || {}

          result = self.class.call_tool tool_name, arguments
          
          {
            jsonrpc: JSON_RPC_VERSION,
            id: data['id'],
            result: {
              content: [
                {
                  type: 'text',
                  text: result
                }
              ]
            }
          }
        rescue => e
          error_response data['id'], JSON_RPC_INTERNAL_ERROR, e.message
        end
        
        def error_response(id, code, message)
          {
            jsonrpc: JSON_RPC_VERSION,
            id: id,
            error: {
              code: code,
              message: message
            }
          }
        end

      end
    end
  end
end