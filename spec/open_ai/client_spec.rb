require 'minitest_helper'

describe Rasti::AI::OpenAI::Client do

  let(:api_url) { 'https://api.openai.com/v1/chat/completions' }

  def user_message(content)
    {
      role: Rasti::AI::OpenAI::Roles::USER,
      content: content
    }
  end

  describe 'Basic message' do

    let(:question) { 'who is Messi?' }

    let(:answer) { 'Lionel Messi is the best player ever' }

    def stub_open_ai_chat_completions(api_key:nil, model:nil)
      api_key ||= Rasti::AI.openai_api_key
      model ||= Rasti::AI.openai_default_model

      stub_request(:post, api_url)
        .with(
          headers: {'Authorization' => "Bearer #{api_key}"},
          body: read_resource('open_ai/basic_request.json', model: model, prompt: question)
        )
        .to_return(body: read_resource('open_ai/basic_response.json', content: answer))
    end

    def assert_response_content(response, expected_content)
      assert_equal expected_content, response.dig('choices', 0, 'message', 'content')
    end

    it 'Default API key, model and logger' do
      stub_open_ai_chat_completions

      client = Rasti::AI::OpenAI::Client.new

      response = client.chat_completions messages: [user_message(question)]

      assert_response_content response, answer
    end

    it 'Custom API key' do
      custom_api_key = SecureRandom.uuid

      stub_open_ai_chat_completions api_key: custom_api_key

      client = Rasti::AI::OpenAI::Client.new api_key: custom_api_key

      response = client.chat_completions messages: [user_message(question)]

      assert_response_content response, answer
    end

    it 'Custom model' do
      custom_model = SecureRandom.uuid

      stub_open_ai_chat_completions model: custom_model

      client = Rasti::AI::OpenAI::Client.new

      response = client.chat_completions messages: [user_message(question)],
                                         model: custom_model

      assert_response_content response, answer
    end

    it 'Custom logger' do
      log_output = StringIO.new
      logger = Logger.new log_output

      stub_open_ai_chat_completions

      client = Rasti::AI::OpenAI::Client.new logger: logger

      response = client.chat_completions messages: [user_message(question)]

      assert_response_content response, answer

      refute_empty log_output.string
    end

  end

  it 'Request error' do
    stub_request(:post, api_url)
      .to_return(status: 400, body: '{"error": {"message": "Test error"}}')

    client = Rasti::AI::OpenAI::Client.new

    error = assert_raises(Rasti::AI::Errors::RequestFail) do
      client.chat_completions messages: ['invalid message']
    end

    assert_includes error.message, 'Response: 400'
  end

  it 'Tool call' do
    question = 'how many goals did messi for barca'

    tool_name = 'player_goals'

    tool = {
      type: 'function',
      function: {
        name: tool_name,
        description: 'Gets the number of goals scored by a player for a specific team',
        parameters: {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Full name of the player'
            },
            team: {
              type: 'string',
              description: 'Name of the team the player was part of'
            }
          },
          required: ['name', 'team']
        }
      }
    }

    arguments = {
      name: 'Lionel Messi',
      team: 'FC Barcelona'
    }

    stub_request(:post, api_url)
      .with(
        headers: {'Authorization' => "Bearer #{Rasti::AI.openai_api_key}"},
        body: read_resource(
          'open_ai/tool_request.json',
          model: Rasti::AI.openai_default_model,
          prompt: question,
          tools: [tool]
        )
      )
      .to_return(body: read_resource('open_ai/tool_response.json', name: tool_name, arguments: arguments))

    client = Rasti::AI::OpenAI::Client.new

    response = client.chat_completions messages: [user_message(question)],
                                       tools: [tool]

    tool_call = response.dig('choices', 0, 'message', 'tool_calls', 0, 'function')

    assert_equal tool_name, tool_call['name']
    assert_equal JSON.dump(arguments), tool_call['arguments']
  end

end