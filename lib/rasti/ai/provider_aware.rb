module Rasti
  module AI
    module ProviderAware

      private

      def provider
        @provider ||= provider_module::Provider.new
      end

      def provider_module
        Object.const_get self.class.name.split('::')[0..-2].join('::')
      end

    end
  end
end
