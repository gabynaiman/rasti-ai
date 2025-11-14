module Rasti
  module AI
    module LLM
      module OpenAI
        class Client

          BASE_URL = 'https://api.openai.com/v1'.freeze

          def initialize(api_key:nil, logger:nil)
            @api_key = api_key || Rasti::AI.openai_api_key
            @logger = logger || Rasti::AI.logger
          end

          def chat_completions(messages:, model:nil, tools:[], response_format: nil)
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

          attr_reader :api_key, :logger

          def post(relative_url, body)
            url = "#{BASE_URL}#{relative_url}"
            uri = URI(url)

            logger.info(self.class) { "POST #{url}" }
            logger.debug(self.class) { JSON.pretty_generate(body) }

            request = Net::HTTP::Post.new uri
            request['Authorization'] = "Bearer #{api_key}"
            request['Content-Type'] = 'application/json'
            request.body = JSON.dump(body)

            http = Net::HTTP.new uri.host, uri.port
            http.use_ssl = uri.scheme == 'https'

            response = http.request request

            logger.info(self.class) { "Response #{response.code}" }
            logger.debug(self.class) { response.body }

            raise Errors::RequestFail.new(url, body, response) unless response.is_a? Net::HTTPSuccess

            JSON.parse response.body
          end

        end
      end

    end
  end
end