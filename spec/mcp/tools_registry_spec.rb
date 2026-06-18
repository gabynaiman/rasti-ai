require 'minitest_helper'

describe Rasti::AI::MCP::ToolsRegistry do

  class NoDescriptionTool < Rasti::AI::Tool
    def execute(form)
      {ok: true}
    end
  end

  let(:tools_registry) { Rasti::AI::MCP::ToolsRegistry.new }

  describe 'Register with tool instance' do

    it 'Derives name, description and schema from tool class' do
      tools_registry.register tool: HelloWorldTool.new

      assert_equal [Rasti::AI::ToolSerializer.serialize(HelloWorldTool)], tools_registry.serializations
    end

    it 'Overrides name when name is provided' do
      tools_registry.register name: 'custom_name', tool: HelloWorldTool.new

      assert_equal 'custom_name', tools_registry.serializations.first[:name]
    end

    it 'Overrides description when description is provided' do
      tools_registry.register tool: HelloWorldTool.new, description: 'Custom description'

      assert_equal 'Custom description', tools_registry.serializations.first[:description]
    end

    it 'Overrides input schema when input_schema is provided' do
      schema = {type: 'object', properties: {x: {type: 'string'}}}

      tools_registry.register tool: HelloWorldTool.new, input_schema: schema

      assert_equal schema, tools_registry.serializations.first[:inputSchema]
    end

    it 'Omits description when tool class has none' do
      tools_registry.register tool: NoDescriptionTool.new

      refute tools_registry.serializations.first.key? :description
    end

    it 'Executes tool when called' do
      tools_registry.register tool: HelloWorldTool.new

      result = tools_registry.call 'hello_world_tool'

      assert_equal '{"text":"Hello world"}', result
    end

    it 'Executes tool with arguments when called' do
      tools_registry.register tool: SumTool.new

      result = tools_registry.call 'sum_tool', 'number_a' => 3, 'number_b' => 4

      assert_equal '{"result":7.0}', result
    end

  end

  describe 'Register with form and block' do

    it 'Builds schema from form class' do
      tools_registry.register name: 'sum', description: 'Sum two numbers', form: SumTool::Form do |args|
        (args['number_a'] + args['number_b']).to_s
      end

      expected_serialization = {
        name: 'sum',
        description: 'Sum two numbers',
        inputSchema: Rasti::AI::ToolSerializer.serialize_form(SumTool::Form)
      }

      assert_equal [expected_serialization], tools_registry.serializations
    end

    it 'Executes block when called' do
      tools_registry.register name: 'sum', description: 'Sum', form: SumTool::Form do |args|
        (args['number_a'] + args['number_b']).to_s
      end

      result = tools_registry.call 'sum', 'number_a' => 1.0, 'number_b' => 2.0

      assert_equal '3.0', result
    end

  end

  describe 'Register with input_schema and block' do

    let(:schema) do
      {
        type: 'object',
        properties: {
          query: {type: 'string', description: 'Search query'},
          limit: {type: 'integer'}
        },
        required: ['query']
      }
    end

    it 'Uses provided input_schema as-is' do
      tools_registry.register name: 'search', description: 'Search content', input_schema: schema do |args|
        "results for #{args['query']}"
      end

      expected_serialization = {
        name: 'search',
        description: 'Search content',
        inputSchema: schema
      }

      assert_equal [expected_serialization], tools_registry.serializations
    end

    it 'Supports nested schemas' do
      nested_schema = {
        type: 'object',
        properties: {
          title: {type: 'string'},
          filters: {
            type: 'object',
            properties: {
              category: {type: 'string', enum: ['sales', 'ops']},
              date_range: {
                type: 'object',
                properties: {
                  from: {type: 'string', format: 'date'},
                  to: {type: 'string', format: 'date'}
                },
                required: ['from', 'to']
              }
            }
          }
        },
        required: ['title']
      }

      tools_registry.register name: 'report', description: 'Generate report', input_schema: nested_schema do |args|
        "report: #{args['title']}"
      end

      assert_equal nested_schema, tools_registry.serializations.first[:inputSchema]
    end

    it 'Executes block when called' do
      tools_registry.register name: 'search', description: 'Search', input_schema: schema do |args|
        "results for #{args['query']}"
      end

      result = tools_registry.call 'search', 'query' => 'ruby'

      assert_equal 'results for ruby', result
    end

  end

  describe 'Register combinations' do

    it 'Registers multiple tools' do
      tools_registry.register tool: HelloWorldTool.new
      tools_registry.register tool: SumTool.new

      assert_equal 2, tools_registry.serializations.length
      assert_equal 'hello_world_tool', tools_registry.serializations[0][:name]
      assert_equal 'sum_tool', tools_registry.serializations[1][:name]
    end

    it 'input_schema overrides form when both provided' do
      custom_schema = {type: 'object', properties: {x: {type: 'string'}}}

      tools_registry.register(
        name: 'mixed',
        description: 'Mixed',
        form: SumTool::Form,
        input_schema: custom_schema
      ) { |args| args.to_s }

      assert_equal custom_schema, tools_registry.serializations.first[:inputSchema]
    end

    it 'Block overrides tool executor when both provided' do
      tools_registry.register tool: HelloWorldTool.new do |_args|
        'overridden'
      end

      result = tools_registry.call 'hello_world_tool'

      assert_equal 'overridden', result
    end

  end

  describe 'Validation' do

    it 'Raises when name is missing and no tool provided' do
      error = assert_raises ArgumentError do
        tools_registry.register(description: 'No name') { |_| 'ok' }
      end

      assert_equal 'name is required', error.message
    end

    it 'Raises when no executor provided' do
      error = assert_raises ArgumentError do
        tools_registry.register name: 'no_exec', description: 'No executor'
      end

      assert_match 'no_exec', error.message
    end

    it 'Raises when calling unknown tool' do
      error = assert_raises RuntimeError do
        tools_registry.call 'nonexistent'
      end

      assert_equal 'Tool nonexistent not found', error.message
    end

  end

end
