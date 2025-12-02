module Rasti
  module AI
    module OpenAI
      class Client

        BASE_URL = 'https://api.openai.com/v1'.freeze

        RETRYABLE_STATUS_CODES = [502, 503, 504].freeze

        def initialize(api_key:nil, logger:nil, http_connect_timeout:nil, http_read_timeout:nil, http_max_retries:nil)
          @api_key = api_key || Rasti::AI.openai_api_key
          @logger = logger || Rasti::AI.logger
          @http_connect_timeout = http_connect_timeout || Rasti::AI.http_connect_timeout
          @http_read_timeout = http_read_timeout || Rasti::AI.http_read_timeout
          @http_max_retries = http_max_retries || Rasti::AI.http_max_retries
        end

        def chat_completions(messages:, model:nil, tools:[], response_format:nil)
          body = {
            model: model || Rasti::AI.openai_default_model,
            messages: messages,
            tools: tools,
            tool_choice: tools.empty? ? 'none' : 'auto'
          }

          body[:response_format] = response_format unless response_format.nil?

          post '/chat/completions', body
        end

        private

        attr_reader :api_key, :logger, :http_connect_timeout, :http_read_timeout, :http_max_retries

        def post(relative_url, body)
          max_retries = http_max_retries
          retry_count = 0

          begin
            url = "#{BASE_URL}#{relative_url}"
            uri = URI.parse url

            logger.info(self.class) { "POST #{url}" }
            logger.debug(self.class) { JSON.pretty_generate(body) }

            request = Net::HTTP::Post.new uri
            request['Authorization'] = "Bearer #{api_key}"
            request['Content-Type'] = 'application/json'
            request.body = JSON.dump body

            http = Net::HTTP.new uri.host, uri.port
            http.use_ssl = (uri.scheme == 'https')

            http.open_timeout = http_connect_timeout
            http.read_timeout = http_read_timeout

            response = http.request request

            logger.info(self.class) { "Response #{response.code}" }
            logger.debug(self.class) { response.body }

            if !response.is_a?(Net::HTTPSuccess) || RETRYABLE_STATUS_CODES.include?(response.code.to_i)
              raise Errors::RequestFail.new(url, body, response)
            end

            JSON.parse response.body

          rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, Errors::RequestFail => e
            if retry_count < max_retries
              retry_count += 1
              logger.warn(self.class) { "#{e.class.name}: #{e.message} (#{retry_count}/#{max_retries})" }
              sleep retry_count
              retry
            end
            raise
          end
        end

      end
    end

  end
end