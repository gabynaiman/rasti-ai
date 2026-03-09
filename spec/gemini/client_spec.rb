require 'minitest_helper'

describe Rasti::AI::Gemini::Client do

  def api_url(model:nil, api_key:nil)
    model ||= Rasti::AI.gemini_default_model
    api_key ||= Rasti::AI.gemini_api_key
    "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}"
  end

  def user_content(text)
    {
      role: Rasti::AI::Gemini::Roles::USER,
      parts: [{text: text}]
    }
  end

  describe 'Basic message' do

    let(:question) { 'who is Messi?' }

    let(:answer) { 'Lionel Messi is the best player ever' }

    def stub_gemini_generate_content(api_key:nil, model:nil)
      stub_request(:post, api_url(model: model, api_key: api_key))
        .with(
          body: read_resource('gemini/basic_request.json', prompt: question)
        )
        .to_return(body: read_resource('gemini/basic_response.json', content: answer))
    end

    def assert_response_content(response, expected_content)
      assert_equal expected_content, response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    end

    it 'Default API key, model and logger' do
      stub_gemini_generate_content

      client = Rasti::AI::Gemini::Client.new

      response = client.generate_content contents: [user_content(question)]

      assert_response_content response, answer
    end

    it 'Custom API key' do
      custom_api_key = SecureRandom.uuid

      stub_gemini_generate_content api_key: custom_api_key

      client = Rasti::AI::Gemini::Client.new api_key: custom_api_key

      response = client.generate_content contents: [user_content(question)]

      assert_response_content response, answer
    end

    it 'Custom model' do
      custom_model = SecureRandom.uuid

      stub_gemini_generate_content model: custom_model

      client = Rasti::AI::Gemini::Client.new

      response = client.generate_content contents: [user_content(question)],
                                         model: custom_model

      assert_response_content response, answer
    end

    it 'Custom logger' do
      log_output = StringIO.new
      logger = Logger.new log_output

      stub_gemini_generate_content

      client = Rasti::AI::Gemini::Client.new logger: logger

      response = client.generate_content contents: [user_content(question)]

      assert_response_content response, answer

      refute_empty log_output.string
    end

  end

  it 'Request error' do
    stub_request(:post, api_url)
      .to_return(status: 400, body: '{"error": {"message": "Test error"}}')

    client = Rasti::AI::Gemini::Client.new

    error = assert_raises(Rasti::AI::Errors::RequestFail) do
      client.generate_content contents: ['invalid']
    end

    assert_includes error.message, 'Response: 400'
  end

  it 'Tool call' do
    question = 'how many goals did messi for barca'

    tool_name = 'player_goals'

    tool = {
      function_declarations: [
        {
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
      ]
    }

    arguments = {
      name: 'Lionel Messi',
      team: 'FC Barcelona'
    }

    stub_request(:post, api_url)
      .with(
        body: read_resource(
          'gemini/tool_request.json',
          prompt: question,
          tools: [tool]
        )
      )
      .to_return(body: read_resource('gemini/tool_response.json', name: tool_name, arguments: arguments))

    client = Rasti::AI::Gemini::Client.new

    response = client.generate_content contents: [user_content(question)],
                                       tools: [tool]

    function_call = response.dig('candidates', 0, 'content', 'parts', 0, 'functionCall')

    assert_equal tool_name, function_call['name']
    assert_equal({'name' => 'Lionel Messi', 'team' => 'FC Barcelona'}, function_call['args'])
  end

end
