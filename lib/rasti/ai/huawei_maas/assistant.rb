module Rasti
  module AI
    module HuaweiMaaS
      class Assistant < Rasti::AI::OpenAI::Assistant

        private

        def build_default_client
          Client.new
        end

      end
    end
  end
end
