module Rasti
  module AI
    module HuaweiMaaS
      class Provider < Rasti::AI::OpenAI::Provider

        def name
          :huawei_maas
        end

        def default_model
          Rasti::AI.huawei_maas_default_model
        end

        def default_api_key
          Rasti::AI.huawei_maas_api_key
        end

        def base_url
          'https://api-ap-southeast-1.modelarts-maas.com/v2'
        end

      end
    end
  end
end
