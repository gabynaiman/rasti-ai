module Rasti
  module AI
    class AssistantState

      attr_reader :messages, :context

      def initialize(context:nil)
        @messages = []
        @cache = {}
        @context = context
      end

      def fetch(key, &block)
        cache[key] = block.call unless cache.key? key
        cache[key]
      end

      private

      attr_reader :cache

    end
  end
end
