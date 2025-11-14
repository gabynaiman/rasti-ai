module Rasti
  module AI
    class Agent

      def initialize(session:, logger:nil)
        @orchestrator = session.build_orchestrator logger: logger
      end

      def call(prompt)
        orchestrator.call prompt
      end

      private

      attr_reader :orchestrator

    end
  end
end