module Rasti
  module AI
    module MCP
      class Configuration < Rasti::Model

        attribute :url,           Rasti::Types::String
        attribute :allowed_tools, Rasti::Types::Array[Rasti::Types::String], default: nil

      end
    end
  end
end