module Rasti
  module AI
    module MCP
      class Client

        def initialize(url:, allowed_tools:nil, logger:nil)
          @url = url
          @allowed_tools = allowed_tools
          @logger = logger || Rasti::AI.logger
        end

        def list_tools
          result = request_mcp 'tools/list'
          tools = result['tools']
          if allowed_tools
            tools.select { |tool| allowed_tools.include? tool['name'] }
          else
            tools
          end
        end

        def call_tool(name, arguments={})
          raise "Invalid tool: #{name}" if allowed_tools && !allowed_tools.include?(name)
          result = request_mcp 'tools/call', name: name, arguments: arguments
          JSON.dump result['content'][0]
        end

        private

        attr_reader :url, :allowed_tools, :logger

        def request_mcp(method, params={})
          uri = URI.parse url

          http = Net::HTTP.new uri.host, uri.port
          http.use_ssl = uri.scheme == 'https'

          request = Net::HTTP::Post.new uri.path

          request['Content-Type'] = 'application/json'

          body = {
            jsonrpc: '2.0',
            method: method,
            params: params
          }
          request.body = JSON.dump body

          logger.info(self.class) { "POST #{url} -> #{method}" }
          logger.debug(self.class) { JSON.pretty_generate(params) }
          
          response = http.request request

          logger.info(self.class) { "Response #{response.code}" }
          logger.debug(self.class) { response.body }

          json = JSON.parse response.body

          raise "MCP Error: #{json['error']['message']}" if json['error']
          raise "MCP Error: invalid result" unless json['result']

          json['result']
        end

      end
    end
  end
end