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

        def serialize_name(tool_class)
          Inflecto.underscore Inflecto.demodulize(tool_class.name)
        end

        def serialize_form(form_class)
          json_schema_from_model_schema form_class.to_schema
        end

        private

        def json_schema_from_model_schema(schema)
          properties = schema[:attributes].each_with_object({}) do |attribute, hash|
            hash[attribute[:name]] = json_schema_for_attribute(attribute)
          end

          result = {type: 'object', properties: properties}

          required = schema[:attributes].select { |a| (a[:options] || {})[:required] }.map { |a| a[:name] }
          result[:required] = required unless required.empty?

          result
        end

        def json_schema_for_attribute(attribute)
          serialization = {}

          description = (attribute[:options] || {})[:description]
          serialization[:description] = normalize_description(description) if description

          serialization.merge! json_schema_for_type(attribute)

          if attribute[:type] == :enum
            values = attribute[:values].join(', ')
            if serialization[:description]
              serialization[:description] += " (#{values})"
            else
              serialization[:description] = values
            end
          end

          serialization
        end

        def json_schema_for_type(type_hash)
          case type_hash[:type]
          when :string, :symbol then {type: 'string'}
          when :integer         then {type: 'integer'}
          when :float           then {type: 'number'}
          when :boolean         then {type: 'boolean'}
          when :time            then {type: 'string', format: 'date'}
          when :enum            then {type: 'string', enum: type_hash[:values]}
          when :array           then {type: 'array', items: json_schema_for_type(type_hash[:items])}
          when :model           then json_schema_from_model_schema(type_hash[:schema])
          when :hash            then {type: 'object'}
          else                       {}
          end
        end

        def normalize_description(description)
          description.split("\n").map(&:strip).join(' ').strip
        end

      end
    end
  end
end
