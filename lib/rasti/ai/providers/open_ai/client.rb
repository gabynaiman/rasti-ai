module Rasti
  module AI
    module Providers
      module OpenAI
        class Client

          BASE_URL = 'https://api.openai.com/v1'.freeze

          def initialize(api_key:nil, logger:nil)
            @api_key = api_key || Rasti::AI.openai_api_key
            @logger = logger || Rasti::AI.logger
          end

          def chat_completions(messages:, model:nil, tools:[])
            body = {
              model: model || Rasti::AI.openai_default_model,
              messages: messages,
              tools: tools,
              tool_choice: tools.empty? ? 'none' : 'auto'
            }

            post '/chat/completions', body
          end

          private

          attr_reader :api_key, :logger

          def post(relative_url, body)
            url = "#{BASE_URL}#{relative_url}"

            headers = {'Authorization' => "Bearer #{api_key}"}

            logger.info(self.class) { "POST #{url}" }
            logger.debug(self.class) { JSON.pretty_generate(body) }

            response = HTTP.headers(headers)
                           .post(url, json: body)

            logger.info(self.class) { "Response #{response.status}" }
            logger.debug(self.class) { response.body.to_s }

            raise Errors::RequestFail.new(url, body, response) unless response.status.ok?

            JSON.parse response.body.to_s
          end

        end
      end

    end
  end
end