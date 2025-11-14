module Rasti
  module AI
    class Message < Rasti::Model

      attribute :role,         Rasti::AI::Roles
      attribute :content,      Rasti::Types::String
      attribute :tool_calls
      attribute :tool_call_id, Rasti::Types::String     
      
      Rasti::AI::Roles.values.each do |role|
        define_singleton_method "from_#{role}" do |attributes|
          new attributes.merge(role: role)
        end
      end

    end
  end
end