module Rasti
  module AI
    module MCP
      class Server

        extend ClassConfig

        attr_config :server_name,    'MCP Server'
        attr_config :server_version, '1.0.0'
        attr_config :relative_path,  '/mcp'
        attr_config :tools_loader

        class << self
          def load_tools(&block)
            self.tools_loader = block
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

          tools_registry = build_tools_registry request

          response = case data['method']
          when 'initialize'
            handle_initialize data
          when 'tools/list'
            handle_tools_list data, tools_registry
          when 'tools/call'
            handle_tool_call data, tools_registry
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

        def build_tools_registry(request)
          tools_registry = ToolsRegistry.new
          self.class.tools_loader.call tools_registry, request if self.class.tools_loader
          tools_registry
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

        def handle_tools_list(data, tools_registry)
          {
            jsonrpc: JSON_RPC_VERSION,
            id: data['id'],
            result: {
              tools: tools_registry.serializations
            }
          }
        end

        def handle_tool_call(data, tools_registry)
          tool_name = data['params']['name']
          arguments = data['params']['arguments'] || {}

          result = tools_registry.call tool_name, arguments

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
