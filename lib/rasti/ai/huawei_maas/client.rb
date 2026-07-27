module Rasti
  module AI
    module HuaweiMaaS
      class Client < Rasti::AI::OpenAI::Client

        private

        def default_api_key
          Rasti::AI.huawei_maas_api_key
        end

        def default_model
          Rasti::AI.huawei_maas_default_model
        end

        def provider_name
          'huawei_maas'
        end

        def base_url
          'https://api-ap-southeast-1.modelarts-maas.com/v2'
        end

      end
    end
  end
end
