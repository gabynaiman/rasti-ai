module Rasti
  module AI
    module Errors

      class RequestFail < StandardError

        attr_reader :url, :body, :response

        def initialize(url, body, response)
          @url = url
          @body = body
          @response = response
        end

        def message
          "Request fail\nRequest: #{url}\n#{JSON.pretty_generate(body)}\nResponse: #{response.status}\n#{response.body.to_s}"
        end

      end

      class ToolSerializationError < StandardError

        def initialize(tool_class)
          super "Tool serialization error: #{tool_class}"
        end

      end

      class UndefinedTool < StandardError

        def initialize(tool_name)
          super "Undefined tool #{tool_name}"
        end

      end

    end
  end
end