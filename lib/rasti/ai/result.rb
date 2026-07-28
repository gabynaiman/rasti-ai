module Rasti
  module AI
    class Result < Rasti::Model

      attribute :content, Rasti::Types::String
      attribute :usage
      attribute :raw

    end
  end
end
