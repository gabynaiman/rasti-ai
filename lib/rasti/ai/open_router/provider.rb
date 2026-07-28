module Rasti
  module AI
    module OpenRouter
      class Provider < Rasti::AI::OpenAI::Provider

        def name
          :open_router
        end

        def default_model
          Rasti::AI.openrouter_default_model
        end

        def default_api_key
          Rasti::AI.openrouter_api_key
        end

        def base_url
          'https://openrouter.ai/api/v1'
        end

      end
    end
  end
end
