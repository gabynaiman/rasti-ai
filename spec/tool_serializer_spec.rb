require 'minitest_helper'

describe Rasti::AI::ToolSerializer do

  let(:serializer) { Rasti::AI::ToolSerializer }

  def build_tool_class(form_class=nil)
    tool_class = Minitest::Mock.new
    tool_class.expect :name, 'CallCustomFunction'
    tool_class.expect :form, form_class if form_class
    tool_class
  end

  def build_serializaton(param_name:, param_type:)
    {
      name: 'call_custom_function',
      inputSchema: {
        type: 'object',
        properties: {
          param_name.to_sym => {
            type: param_type
          }
        }
      }
    }
  end

  it 'Basic tool' do
    tool_class = build_tool_class

    serialization = serializer.serialize tool_class

    expeted_serialization = {
      name: 'call_custom_function'
    }

    assert_equal expeted_serialization, serialization

    tool_class.verify
  end

  it 'With description' do
    tool_class = build_tool_class
    tool_class.expect :description, 'Call custom function without arguments'

    serialization = serializer.serialize tool_class

    expeted_serialization = {
      name: 'call_custom_function',
      description: 'Call custom function without arguments',
    }

    assert_equal expeted_serialization, serialization

    tool_class.verify
  end

  describe 'Arguments' do

    describe 'Types' do

      it 'String' do
        form_class = Rasti::Form[text: Rasti::Types::String]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'text', param_type: 'string'

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      it 'Integer' do
        form_class = Rasti::Form[int: Rasti::Types::Integer]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'int', param_type: 'integer'

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      it 'Number' do
        form_class = Rasti::Form[number: Rasti::Types::Float]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'number', param_type: 'number'

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      it 'Boolean' do
        form_class = Rasti::Form[bool: Rasti::Types::Boolean]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'bool', param_type: 'boolean'

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      it 'Time with date and time' do
        form_class = Rasti::Form[timestamp: Rasti::Types::Time['%Y-%m-%dT%H:%M:%S%z']]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'timestamp', param_type: 'string'
        expeted_serialization[:inputSchema][:properties][:timestamp][:format] = 'date-time'

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      it 'Time with milliseconds and timezone' do
        form_class = Rasti::Form[started_at: Rasti::Types::Time['%FT%T.%L%z']]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'started_at', param_type: 'string'
        expeted_serialization[:inputSchema][:properties][:started_at][:format] = 'date-time'

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      it 'Time with date only' do
        form_class = Rasti::Form[day: Rasti::Types::Time['%Y-%m-%d']]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'day', param_type: 'string'
        expeted_serialization[:inputSchema][:properties][:day][:format] = 'date'

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      it 'Enum' do
        form_class = Rasti::Form[option: Rasti::Types::Enum['option_1', 'option_2']]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'option', param_type: 'string'
        expeted_serialization[:inputSchema][:properties][:option][:enum] = ['option_1', 'option_2']
        expeted_serialization[:inputSchema][:properties][:option][:description] = 'option_1, option_2'

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      it 'Object' do
        inner_form_class = Rasti::Form[text: Rasti::Types::String, int: Rasti::Types::Integer]
        form_class = Rasti::Form[form: Rasti::Types::Model[inner_form_class]]

        tool_class = build_tool_class form_class

        serialization = serializer.serialize tool_class

        expeted_serialization = build_serializaton param_name: 'form', param_type: 'object'
        expeted_serialization[:inputSchema][:properties][:form][:properties] = {
          text: {type: 'string'},
          int: {type: 'integer'}
        }

        assert_equal expeted_serialization, serialization

        tool_class.verify
      end

      describe 'Array' do

        it 'String' do
          form_class = Rasti::Form[texts: Rasti::Types::Array[Rasti::Types::String]]

          tool_class = build_tool_class form_class

          serialization = serializer.serialize tool_class

          expeted_serialization = build_serializaton param_name: 'texts', param_type: 'array'
          expeted_serialization[:inputSchema][:properties][:texts][:items] = {type: 'string'}

          assert_equal expeted_serialization, serialization

          tool_class.verify
        end

        it 'Number' do
          form_class = Rasti::Form[numbers: Rasti::Types::Array[Rasti::Types::Float]]

          tool_class = build_tool_class form_class

          serialization = serializer.serialize tool_class

          expeted_serialization = build_serializaton param_name: 'numbers', param_type: 'array'
          expeted_serialization[:inputSchema][:properties][:numbers][:items] = {type: 'number'}

          assert_equal expeted_serialization, serialization

          tool_class.verify
        end

        it 'Object' do
          inner_form_class = Rasti::Form[text: Rasti::Types::String, int: Rasti::Types::Integer]
          form_class = Rasti::Form[forms: Rasti::Types::Array[Rasti::Types::Model[inner_form_class]]]

          tool_class = build_tool_class form_class

          serialization = serializer.serialize tool_class

          expeted_serialization = build_serializaton param_name: 'forms', param_type: 'array'
          expeted_serialization[:inputSchema][:properties][:forms][:items] = {
            type: 'object',
            properties: {
              text: {type: 'string'},
              int: {type: 'integer'}
            }
          }

          assert_equal expeted_serialization, serialization

          tool_class.verify
        end

      end

    end

    it 'Required' do
      form_class = Class.new Rasti::Form do
        attribute :text, Rasti::Types::String, required: true
        attribute :int, Rasti::Types::Integer, required: false
      end

      tool_class = build_tool_class form_class

      serialization = serializer.serialize tool_class

      expeted_serialization = build_serializaton param_name: 'form', param_type: 'object'
      expeted_serialization[:inputSchema][:properties] = {
        text: {type: 'string'},
        int: {type: 'integer'}
      }
      expeted_serialization[:inputSchema][:required] = [:text]

      assert_equal expeted_serialization, serialization

      tool_class.verify
    end

    it 'Description' do
      form_class = Class.new Rasti::Form do
        attribute :text, Rasti::Types::String, description: 'Text param'
        attribute :int, Rasti::Types::Integer, description: 'Int param'
      end

      tool_class = build_tool_class form_class

      serialization = serializer.serialize tool_class

      expeted_serialization = build_serializaton param_name: 'form', param_type: 'object'
      expeted_serialization[:inputSchema][:properties] = {
        text: {
          description: 'Text param',
          type: 'string'
        },
        int: {
          description: 'Int param',
          type: 'integer'
        }
      }

      assert_equal expeted_serialization, serialization

      tool_class.verify
    end

  end

  it 'Custom registered type' do
    custom_type = Class.new
    Rasti::Model::Schema.register_type_serializer(custom_type) { {type: :string} }

    form_class = Rasti::Form[value: custom_type]
    tool_class = build_tool_class form_class

    serialization = serializer.serialize tool_class

    expected_serialization = build_serializaton param_name: 'value', param_type: 'string'

    assert_equal expected_serialization, serialization

    tool_class.verify
  end

  it 'Unknown type serializes without constraints' do
    form_class = Rasti::Form[obj: Object]
    tool_class = build_tool_class form_class

    serialization = serializer.serialize tool_class

    expected_serialization = {
      name: 'call_custom_function',
      inputSchema: {
        type: 'object',
        properties: {
          obj: {}
        }
      }
    }

    assert_equal expected_serialization, serialization

    tool_class.verify
  end

end