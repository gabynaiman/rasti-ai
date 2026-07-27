module Rasti
  module AI
    module OpenRouter
      class Client < Rasti::AI::OpenAI::Client

        private

        def default_api_key
          Rasti::AI.openrouter_api_key
        end

        def default_model
          Rasti::AI.openrouter_default_model
        end

        def provider_name
          'open_router'
        end

        def base_url
          'https://openrouter.ai/api/v1'
        end

      end
    end
  end
end
