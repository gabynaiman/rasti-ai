module Rasti
  module AI
    module LLM
      module Providers
        
        extend Rasti::Enum

        class OpenAI < Rasti::Enum::Value

          def build_orchestrator(session:, logger:nil)
            LLM::OpenAI::Orchestrator.new session: session,
                                          logger: logger
          end

        end

      end
    end
  end
end