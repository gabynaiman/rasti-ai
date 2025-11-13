module Rasti
  module AI
    class ToolSerializer
      class << self

        def serialize(tool_class)
          serialization = {
            name: serialize_name(tool_class)
          }

          serialization[:description] = normalize_description(tool_class.description) if tool_class.respond_to? :description

          serialization[:inputSchema] = serialize_form(tool_class.form) if tool_class.respond_to? :form

          serialization
          
        rescue => ex
          raise Errors::ToolSerializationError.new(tool_class), cause: ex
        end

        private

        def serialize_name(tool_class)
          Inflecto.underscore Inflecto.demodulize(tool_class.name)
        end

        def serialize_form(form_class)
          serialized_attributes = form_class.attributes.each_with_object({}) do |attribute, hash|
            hash[attribute.name] = serialize_attribute attribute
          end

          serialization = {
            type: 'object',
            properties: serialized_attributes
          }

          required_attributes = form_class.attributes.select { |a| a.option(:required) }

          serialization[:required] = required_attributes.map(&:name) unless required_attributes.empty?

          serialization
        end

        def serialize_attribute(attribute)
          serialization = {}
          
          if attribute.option(:description)
            serialization[:description] = normalize_description attribute.option(:description)
          end
          
          type_serialization = serialize_type attribute.type
          serialization.merge! type_serialization

          if attribute.type.is_a? Types::Enum
            values = "#{type_serialization[:enum].join(', ')}"
            if serialization[:description]
              serialization[:description] += " (#{values})"
            else
              serialization[:description] = values
            end
          end

          serialization
        end

        def serialize_type(type)
          if type == Types::String
            {type: 'string'}

          elsif type == Types::Integer
            {type: 'integer'}

          elsif type == Types::Float
            {type: 'number'}

          elsif type == Types::Boolean
            {type: 'boolean'}

          elsif type.is_a? Types::Time
            {
              type: 'string',
              format: 'date'
            }

          elsif type.is_a? Types::Enum
            {
              type: 'string',
              enum: type.values
            }

          elsif type.is_a? Types::Array
            {
              type: 'array',
              items: serialize_type(type.type)
            }

          elsif type.is_a? Types::Model
            serialize_form(type.model)

          else
            raise "Type not serializable #{type}"
          end
        end

        def normalize_description(description)
          description.split("\n").map(&:strip).join(' ').strip
        end
        
      end
    end
  end
end