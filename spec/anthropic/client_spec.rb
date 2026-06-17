require 'minitest_helper'

describe Rasti::AI::Anthropic::Client do

  let(:api_url) { 'https://api.anthropic.com/v1/messages' }

  def user_message(content)
    {
      role: Rasti::AI::Anthropic::Roles::USER,
      content: content
    }
  end

  describe 'Basic message' do

    let(:question) { 'who is Messi?' }

    let(:answer) { 'Lionel Messi is the best player ever' }

    def stub_anthropic_messages(api_key:nil, model:nil)
      api_key ||= Rasti::AI.anthropic_api_key
      model   ||= Rasti::AI.anthropic_default_model

      stub_request(:post, api_url)
        .with(
          headers: {
            'x-api-key'          => api_key,
            'anthropic-version'  => '2023-06-01'
          },
          body: read_resource('anthropic/basic_request.json', model: model, prompt: question)
        )
        .to_return(body: read_resource('anthropic/basic_response.json', content: answer))
    end

    def assert_response_content(response, expected_content)
      text_block = response['content'].find { |b| b['type'] == 'text' }
      assert_equal expected_content, text_block['text']
    end

    it 'Default API key, model and logger' do
      stub_anthropic_messages

      client = Rasti::AI::Anthropic::Client.new

      response = client.messages messages: [user_message(question)]

      assert_response_content response, answer
    end

    it 'Custom API key' do
      custom_api_key = SecureRandom.uuid

      stub_anthropic_messages api_key: custom_api_key

      client = Rasti::AI::Anthropic::Client.new api_key: custom_api_key

      response = client.messages messages: [user_message(question)]

      assert_response_content response, answer
    end

    it 'Custom model' do
      custom_model = SecureRandom.uuid

      stub_anthropic_messages model: custom_model

      client = Rasti::AI::Anthropic::Client.new

      response = client.messages messages: [user_message(question)], model: custom_model

      assert_response_content response, answer
    end

    it 'Custom logger' do
      log_output = StringIO.new
      logger = Logger.new log_output

      stub_anthropic_messages

      client = Rasti::AI::Anthropic::Client.new logger: logger

      response = client.messages messages: [user_message(question)]

      assert_response_content response, answer

      refute_empty log_output.string
    end

    describe 'Usage tracker' do

      it 'Track usage' do
        stub_anthropic_messages

        tracked = []
        tracker = ->(usage) { tracked << usage }

        client = Rasti::AI::Anthropic::Client.new usage_tracker: tracker

        client.messages messages: [user_message(question)]

        assert_equal 1, tracked.count

        expected_raw = {
          'input_tokens'                => 25,
          'output_tokens'               => 11,
          'cache_creation_input_tokens' => 0,
          'cache_read_input_tokens'     => 0
        }

        usage = tracked[0]
        assert_instance_of Rasti::AI::Usage, usage
        assert_equal 'anthropic',   usage.provider
        assert_equal 'claude-test', usage.model
        assert_equal 25,            usage.input_tokens
        assert_equal 11,            usage.output_tokens
        assert_equal 0,             usage.cached_tokens
        assert_equal 0,             usage.reasoning_tokens
        assert_equal expected_raw,  usage.raw
      end

      it 'Without tracker' do
        stub_anthropic_messages

        client = Rasti::AI::Anthropic::Client.new

        response = client.messages messages: [user_message(question)]

        assert_response_content response, answer
      end

    end

  end

  it 'Request error' do
    stub_request(:post, api_url)
      .to_return(status: 400, body: '{"type":"error","error":{"type":"invalid_request_error","message":"Test error"}}')

    client = Rasti::AI::Anthropic::Client.new

    error = assert_raises(Rasti::AI::Errors::RequestFail) do
      client.messages messages: ['invalid message']
    end

    assert_includes error.message, 'Response: 400'
  end

  it 'Tool call' do
    question  = 'how many goals did messi for barca'
    tool_name = 'player_goals'

    tool = {
      name:         tool_name,
      description:  'Gets the number of goals scored by a player for a specific team',
      input_schema: {
        type:       'object',
        properties: {
          name: {
            type:        'string',
            description: 'Full name of the player'
          },
          team: {
            type:        'string',
            description: 'Name of the team the player was part of'
          }
        },
        required: ['name', 'team']
      }
    }

    arguments = {
      name: 'Lionel Messi',
      team: 'FC Barcelona'
    }

    stub_request(:post, api_url)
      .with(
        headers: {
          'x-api-key'         => Rasti::AI.anthropic_api_key,
          'anthropic-version' => '2023-06-01'
        },
        body: read_resource(
          'anthropic/tool_request.json',
          model:   Rasti::AI.anthropic_default_model,
          prompt:  question,
          tools:   [tool]
        )
      )
      .to_return(body: read_resource('anthropic/tool_response.json', name: tool_name, arguments: arguments))

    client = Rasti::AI::Anthropic::Client.new

    response = client.messages messages:    [{role: 'user', content: question}],
                                tools:       [tool],
                                tool_choice: {type: 'auto'}

    tool_use = response['content'].find { |b| b['type'] == 'tool_use' }

    assert_equal tool_name,                          tool_use['name']
    assert_equal({'name' => 'Lionel Messi', 'team' => 'FC Barcelona'}, tool_use['input'])
  end

end
