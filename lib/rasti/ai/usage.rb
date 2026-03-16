module Rasti
  module AI
    class Usage < Rasti::Model

      attribute :provider,         Rasti::Types::String
      attribute :model,            Rasti::Types::String
      attribute :input_tokens,     Rasti::Types::Integer
      attribute :output_tokens,    Rasti::Types::Integer
      attribute :cached_tokens,    Rasti::Types::Integer
      attribute :reasoning_tokens, Rasti::Types::Integer
      attribute :raw

    end
  end
end
