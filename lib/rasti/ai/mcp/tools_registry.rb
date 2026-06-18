module Rasti
  module AI
    module MCP
      class ToolsRegistry

        Entry = Rasti::Model[:serialization, :executor]

        def initialize
          @entries = {}
        end

        def register(tool: nil, name: nil, description: nil, form: nil, input_schema: nil, &block)
          resolved_name        = resolve_name tool, name
          resolved_description = resolve_description tool, description
          resolved_schema      = resolve_schema tool, form, input_schema
          resolved_executor    = resolve_executor(tool, resolved_name, &block)

          serialization = {name: resolved_name}
          serialization[:description] = resolved_description if resolved_description
          serialization[:inputSchema] = resolved_schema      if resolved_schema

          entries[resolved_name] = Entry.new serialization: serialization, executor: resolved_executor
        end

        def serializations
          entries.values.map(&:serialization)
        end

        def call(name, args={})
          raise "Tool #{name} not found" unless entries.key? name
          entries[name].executor.call args
        end

        private

        attr_reader :entries

        def resolve_name(tool, name)
          return name if name
          return ToolSerializer.serialize_name tool.class if tool
          raise ArgumentError, 'name is required'
        end

        def resolve_description(tool, description)
          return description if description
          tool.class.description if tool && tool.class.respond_to?(:description)
        end

        def resolve_schema(tool, form, input_schema)
          return input_schema if input_schema
          return ToolSerializer.serialize_form form if form
          ToolSerializer.serialize_form tool.class.form if tool && tool.class.respond_to?(:form)
        end

        def resolve_executor(tool, name, &block)
          return block if block
          return tool.method :call if tool
          raise ArgumentError, "executor required: provide a tool or a block for '#{name}'"
        end

      end
    end
  end
end
