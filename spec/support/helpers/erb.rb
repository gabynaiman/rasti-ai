module Support
  module Helpers
    module ERB

      def erb(template, variables={})
        variables_binding = binding.tap do |b|
          variables.each do |key, value|
            b.local_variable_set key, value
          end
        end

        ::ERB.new(template).result variables_binding
      end

    end
  end
end