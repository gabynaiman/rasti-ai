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

    end
  end
end