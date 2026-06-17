module Rasti
  module AI
    module MCP
      class Client

        def initialize(url:, allowed_tools:nil, logger:nil)
          @url          = url
          @allowed_tools = allowed_tools
          @logger       = logger || Rasti::AI.logger
          @session_id   = nil
        end

        def list_tools
          result = request_with_session 'tools/list'
          tools = result['tools']
          if allowed_tools
            tools.select { |tool| allowed_tools.include? tool['name'] }
          else
            tools
          end
        end

        def call_tool(name, arguments={})
          raise "Invalid tool: #{name}" if allowed_tools && !allowed_tools.include?(name)
          result = request_with_session 'tools/call', name: name, arguments: arguments
          JSON.dump result['content'][0]
        end

        private

        attr_reader :url, :allowed_tools, :logger, :session_id

        def request_with_session(method, params={})
          request_mcp method, params
        rescue RuntimeError => e
          raise unless e.message =~ /session/i && session_id.nil?
          initialize_session
          request_mcp method, params
        end

        def initialize_session
          _result, response = request_mcp_raw 'initialize',
            protocolVersion: PROTOCOL_VERSION,
            capabilities: {},
            clientInfo: {name: 'rasti-ai', version: Rasti::AI::VERSION}

          @session_id = response['mcp-session-id']

          send_notification 'notifications/initialized' if session_id
        end

        def send_notification(method)
          uri = URI.parse url
          http = Net::HTTP.new uri.host, uri.port
          http.use_ssl = uri.scheme == 'https'

          req = Net::HTTP::Post.new uri.path
          req['Content-Type'] = 'application/json'
          req['Accept'] = 'application/json, text/event-stream'
          req['Mcp-Session-Id'] = session_id if session_id
          req.body = JSON.dump(jsonrpc: JSON_RPC_VERSION, method: method)

          http.request req
        rescue => e
          logger.warn(self.class) { "Notification failed: #{e.message}" }
        end

        def request_mcp(method, params={})
          result, _response = request_mcp_raw method, params
          result
        end

        def request_mcp_raw(method, params={})
          uri = URI.parse url

          http = Net::HTTP.new uri.host, uri.port
          http.use_ssl = uri.scheme == 'https'

          request = Net::HTTP::Post.new uri.path

          request['Content-Type'] = 'application/json'
          request['Accept'] = 'application/json, text/event-stream'
          request['Mcp-Session-Id'] = session_id if session_id

          body = {
            jsonrpc: JSON_RPC_VERSION,
            id: 1,
            method: method,
            params: params
          }
          request.body = JSON.dump body

          logger.info(self.class) { "POST #{url} -> #{method}" }
          logger.debug(self.class) { JSON.pretty_generate(params) }

          response = http.request request

          logger.info(self.class) { "Response #{response.code}" }
          logger.debug(self.class) { response.body }

          body_str = response.body

          # Handle SSE format (text/event-stream)
          if response['Content-Type']&.include?('text/event-stream')
            body_str = body_str.scan(/^data:\s*(.+)$/).flatten.first || body_str
          end

          json = JSON.parse body_str

          raise "MCP Error: #{json['error']['message']}" if json['error']
          raise "MCP Error: invalid result" unless json['result']

          [json['result'], response]
        end

      end
    end
  end
end