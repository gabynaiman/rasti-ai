require 'minitest_helper'

describe Rasti::AI::HuaweiMaaS::Assistant do

  let(:api_url) { 'https://api-ap-southeast-1.modelarts-maas.com/v2/chat/completions' }

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  it 'Default' do
    stub_request(:post, api_url)
      .with(body: read_resource('open_ai/basic_request.json', model: Rasti::AI.huawei_maas_default_model, prompt: question))
      .to_return(body: read_resource('open_ai/basic_response.json', content: answer))

    assistant = Rasti::AI::HuaweiMaaS::Assistant.new

    response = assistant.call question

    assert_equal answer, response
  end

  describe 'Tools' do

    let(:client) { Minitest::Mock.new }

    let(:tool_response) do
      read_json_resource(
        'open_ai/tool_response.json',
        name: 'goals_by_player',
        arguments: {player: 'Lionel Messi', team: 'Barcelona'}
      )
    end

    let(:tool_result) { '672' }

    let(:answer_with_tool) { 'Lionel Messi scored 672 goals for FC Barcelona.' }

    def basic_response(content)
      read_json_resource('open_ai/basic_response.json', content: content)
    end

    def stub_client_request(role:, content:, response:, tools:[])
      serialized_tools = tools.map do |tool|
        {type: 'function', function: Rasti::AI::ToolSerializer.serialize(tool.class)}
      end

      client.expect :chat_completions, response do |params|
        last_message = params[:messages].last
        last_message[:role] == role &&
          last_message[:content] == content &&
          params[:tools] == serialized_tools
      end
    end

    it 'Call tool' do
      tool = GoalsByPlayer.new

      stub_client_request role: Rasti::AI::HuaweiMaaS::Roles::USER,
                          content: question,
                          tools: [tool],
                          response: tool_response

      stub_client_request role: Rasti::AI::HuaweiMaaS::Roles::TOOL,
                          content: tool_result,
                          tools: [tool],
                          response: basic_response(answer_with_tool)

      assistant = Rasti::AI::HuaweiMaaS::Assistant.new client: client, tools: [tool]

      response = assistant.call question

      assert_equal answer_with_tool, response

      client.verify
    end

  end

end
