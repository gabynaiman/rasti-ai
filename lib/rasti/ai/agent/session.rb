module Rasti
  module AI
    class Agent
      class Session

        attr_reader :id, :configuration

        def initialize(id:nil, configuration:, messages:[])
          @id ||= SecureRandom.uuid
          @configuration = configuration
          @messages = messages
        end

        def add_message(message)
          messages << message
        end

        def all_messages
          system_message = Message.from_system content: configuration.instructions
          [system_message] + messages
        end

        def build_orchestrator(logger:nil)
          configuration.llm.provider.build_orchestrator session: self, 
                                                        logger: logger
        end

        private

        attr_reader :messages

      end
    end
  end
end