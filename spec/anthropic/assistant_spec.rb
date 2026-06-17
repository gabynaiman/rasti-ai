require 'minitest_helper'

describe Rasti::AI::Anthropic::Assistant do

  let(:api_url) { 'https://api.anthropic.com/v1/messages' }

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  def stub_anthropic_messages(question:, answer:, model:nil, json_schema:nil)
    model ||= Rasti::AI.anthropic_default_model

    body = read_json_resource('anthropic/basic_request.json', model: model, prompt: question)

    if json_schema
      body['tools'] = [{
        'name'         => 'structured_output',
        'description'  => 'Return the structured response',
        'input_schema' => {'type' => 'object', 'properties' => json_schema}
      }]
      body['tool_choice'] = {'type' => 'tool', 'name' => 'structured_output'}

      stub_request(:post, api_url)
        .with(body: JSON.dump(body))
        .to_return(body: read_resource('anthropic/tool_response.json', name: 'structured_output', arguments: json_schema))
    else
      stub_request(:post, api_url)
        .with(body: JSON.dump(body))
        .to_return(body: read_resource('anthropic/basic_response.json', content: answer))
    end
  end

  it 'Default' do
    stub_anthropic_messages question: question, answer: answer

    assistant = Rasti::AI::Anthropic::Assistant.new

    response = assistant.call question

    assert_equal answer, response
  end

  describe 'Customized' do

    it 'Client' do
      client_arguments = [
        {
          model:       nil,
          system:      nil,
          tools:       [],
          tool_choice: nil,
          thinking:    nil,
          messages: [
            {
              role:    Rasti::AI::Anthropic::Roles::USER,
              content: question
            }
          ]
        }
      ]

      client_response = read_json_resource 'anthropic/basic_response.json', content: answer

      client = Minitest::Mock.new
      client.expect :messages, client_response, client_arguments

      assistant = Rasti::AI::Anthropic::Assistant.new client: client

      response = assistant.call question

      assert_equal answer, response

      client.verify
    end

    it 'State' do
      context = 'Act as sports journalist'
      state   = Rasti::AI::AssistantState.new context: context

      request_body = {
        model:     Rasti::AI.anthropic_default_model,
        max_tokens: 4096,
        messages: [
          {
            role:    Rasti::AI::Anthropic::Roles::USER,
            content: question
          }
        ],
        system: context
      }

      stub_request(:post, api_url)
        .with(body: JSON.dump(request_body))
        .to_return(body: read_resource('anthropic/basic_response.json', content: answer))

      assistant = Rasti::AI::Anthropic::Assistant.new state: state

      response = assistant.call question

      expected_assistant_message = {
        role:    Rasti::AI::Anthropic::Roles::ASSISTANT,
        content: answer
      }

      assert_equal answer, response
      assert_equal 2, state.messages.count
      assert_equal expected_assistant_message, state.messages.last
    end

    it 'Model' do
      model = SecureRandom.uuid

      stub_anthropic_messages question: question, answer: answer, model: model

      assistant = Rasti::AI::Anthropic::Assistant.new model: model

      response = assistant.call question

      assert_equal answer, response
    end

    it 'Thinking' do
      body = read_json_resource('anthropic/basic_request.json', model: Rasti::AI.anthropic_default_model, prompt: question)
      body['thinking'] = {'type' => 'enabled', 'budget_tokens' => 8_000}

      stub_request(:post, api_url)
        .with(body: JSON.dump(body))
        .to_return(body: read_resource('anthropic/basic_response.json', content: answer))

      assistant = Rasti::AI::Anthropic::Assistant.new thinking: 'medium'

      response = assistant.call question

      assert_equal answer, response
    end

    it 'JSON Schema' do
      json_schema = {'answer' => 'Response answer'}

      stub_anthropic_messages question: question, answer: answer, json_schema: json_schema

      assistant = Rasti::AI::Anthropic::Assistant.new json_schema: json_schema

      response = assistant.call question

      assert_equal 'Response answer', JSON.parse(response)['answer']
    end

  end



  describe 'Tools' do

    let(:client) { Minitest::Mock.new }

    let(:tool_response) do
      read_json_resource(
        'anthropic/tool_response.json',
        name:      'goals_by_player',
        arguments: {
          player: 'Lionel Messi',
          team:   'Barcelona'
        }
      )
    end

    let(:tool_result) { '672' }

    let(:error_message) { 'There was an error using a tool' }

    def basic_response(content)
      read_json_resource 'anthropic/basic_response.json', content: content
    end

    def stub_client_request(role:, content:, response:, tools:[])
      serialized_tools = tools.map do |tool|
        raw = Rasti::AI::ToolSerializer.serialize(tool.class)
        result = raw.dup
        if result.key?(:inputSchema)
          result[:input_schema] = result.delete(:inputSchema)
        end
        result
      end

      client.expect :messages, response do |params|
        last_message = params[:messages].last
        last_message[:role]    == role &&
          last_message[:content] == content &&
          params[:tools]         == serialized_tools
      end
    end

    it 'Call function' do
      tool = GoalsByPlayer.new

      stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                          content:  question,
                          tools:    [tool],
                          response: tool_response

      expected_tool_result_content = [{
        type:        'tool_result',
        tool_use_id: 'toolu_01A09q90qw90lq917835lq9',
        content:     tool_result
      }]

      stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                          content:  expected_tool_result_content,
                          tools:    [tool],
                          response: basic_response(answer)

      assistant = Rasti::AI::Anthropic::Assistant.new client: client, tools: [tool]

      response = assistant.call question

      assert_equal answer, response

      client.verify
    end

    it 'Tool failure' do
      tool = GoalsByPlayer.new
      tool.define_singleton_method :call do |*args|
        raise 'Broken tool'
      end

      stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                          content:  question,
                          tools:    [tool],
                          response: tool_response

      expected_tool_result_content = [{
        type:        'tool_result',
        tool_use_id: 'toolu_01A09q90qw90lq917835lq9',
        content:     'Error: Broken tool'
      }]

      stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                          content:  expected_tool_result_content,
                          tools:    [tool],
                          response: basic_response(error_message)

      assistant = Rasti::AI::Anthropic::Assistant.new client: client, tools: [tool]

      response = assistant.call question

      assert_equal error_message, response

      client.verify
    end

    it 'Undefined tool' do
      stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                          content:  question,
                          response: tool_response

      expected_tool_result_content = [{
        type:        'tool_result',
        tool_use_id: 'toolu_01A09q90qw90lq917835lq9',
        content:     'Error: Undefined tool goals_by_player'
      }]

      stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                          content:  expected_tool_result_content,
                          response: basic_response(error_message)

      assistant = Rasti::AI::Anthropic::Assistant.new client: client, tools: []

      response = assistant.call question

      assert_equal error_message, response

      client.verify
    end

    it 'Cached result' do
      mock = Minitest::Mock.new
      mock.expect :call, tool_result, [{'player' => 'Lionel Messi', 'team' => 'Barcelona'}]

      tool = GoalsByPlayer.new
      tool.define_singleton_method :call do |*args|
        mock.call(*args)
      end

      expected_tool_result_content = [{
        type:        'tool_result',
        tool_use_id: 'toolu_01A09q90qw90lq917835lq9',
        content:     tool_result
      }]

      assistant = Rasti::AI::Anthropic::Assistant.new client: client, tools: [tool]

      5.times do
        stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                            content:  question,
                            tools:    [tool],
                            response: tool_response

        stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                            content:  expected_tool_result_content,
                            tools:    [tool],
                            response: basic_response(answer)

        response = assistant.call question

        assert_equal answer, response
      end

      client.verify
    end

    it 'Custom logger' do
      log_output = StringIO.new
      logger     = Logger.new log_output

      tool = GoalsByPlayer.new

      stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                          content:  question,
                          tools:    [tool],
                          response: tool_response

      expected_tool_result_content = [{
        type:        'tool_result',
        tool_use_id: 'toolu_01A09q90qw90lq917835lq9',
        content:     tool_result
      }]

      stub_client_request role:     Rasti::AI::Anthropic::Roles::USER,
                          content:  expected_tool_result_content,
                          tools:    [tool],
                          response: basic_response(answer)

      assistant = Rasti::AI::Anthropic::Assistant.new client: client, tools: [tool], logger: logger

      response = assistant.call question

      assert_equal answer, response

      refute_empty log_output.string

      client.verify
    end

  end

end
