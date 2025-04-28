module Rasti
  module AI
    module OpenAI
      class AssistantState

        attr_reader :messages

        def initialize(context:nil)
          @messages = []
          @cache = {}

          messages << {role: Roles::SYSTEM, content: context} if context
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
end