module Rasti
  module AI
    module LLM
      class Configuration < Rasti::Model

        attribute :provider, Rasti::Types::TypedEnum[Providers]
        attribute :model,    Rasti::Types::String, default: nil
        attribute :api_key,  Rasti::Types::String, default: nil

      end
    end
  end
end