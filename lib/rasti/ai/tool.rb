module Rasti
  module AI
    class Tool

      def self.form
        constants.include?(:Form) ? const_get(:Form) : Rasti::Form
      end

      def call(params={})
        form = self.class.form.new params
        result = execute form
        serialize result
      end

      private

      def serialize(result)
        JSON.dump result
      end

    end
  end
end