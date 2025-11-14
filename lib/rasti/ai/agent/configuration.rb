module Rasti
  module AI
    class Agent
      class Configuration < Rasti::Model

        attribute :id,            Rasti::Types::String, default: ->(f) { SecureRandom.uuid }
        attribute :name,          Rasti::Types::String
        attribute :instructions,  Rasti::Types::String
        attribute :llm,           Rasti::Types::Model[LLM::Configuration]
        attribute :tools,         nil, default: []
        attribute :mcp_servers,   Rasti::Types::Hash[Rasti::Types::String, Rasti::Types::Model[Rasti::AI::MCP::Configuration]], default: {}
        attribute :output_schema, :cast_json, default: nil

        private

        def cast_json(value)
          return if value.nil?

          if value.is_a? Hash
            value
          elsif value.is_a? String
            JSON.parse value
          else
            raise "Invalid JSON: #{value}"
          end
        end

      end
    end
  end
end