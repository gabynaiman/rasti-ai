require 'minitest_helper'

describe Rasti::AI::OpenAI::Assistant do

  let(:api_url) { 'https://api.openai.com/v1/chat/completions' }

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  def stub_open_ai_chat_completions(model:nil, question:, answer:)
    model ||= Rasti::AI.openai_default_model

    stub_request(:post, api_url)
      .with(body: read_resource('open_ai/basic_request.json', model: model, prompt: question))
      .to_return(body: read_resource('open_ai/basic_response.json', content: answer))
  end


  it 'Default' do
    stub_open_ai_chat_completions question: question, answer: answer

    assistant = Rasti::AI::OpenAI::Assistant.new

    response = assistant.call question

    assert_equal answer, response
  end

  describe 'Customized' do

    it 'Client' do
      client_arguments = [
        {
          model: nil,
          tools: [],
          messages: [
            {
              role: Rasti::AI::OpenAI::Roles::USER,
              content: question
            }
          ]
        }
      ]

      client_response = read_json_resource 'open_ai/basic_response.json', content: answer

      client = Minitest::Mock.new
      client.expect :chat_completions, client_response, client_arguments

      assistant = Rasti::AI::OpenAI::Assistant.new client: client

      response = assistant.call question

      assert_equal answer, response

      client.verify
    end

    it 'State' do
      context = 'Act as sports journalist'
      state = Rasti::AI::OpenAI::AssistantState.new context: context

      request_body = {
        model: Rasti::AI.openai_default_model,
        messages: [
          {
            role: Rasti::AI::OpenAI::Roles::SYSTEM,
            content: context
          },
          {
            role: Rasti::AI::OpenAI::Roles::USER,
            content: question
          }
        ],
        tools: [],
        tool_choice: 'none'
      }

      stub_request(:post, api_url)
        .with(body: JSON.dump(request_body))
        .to_return(body: read_resource('open_ai/basic_response.json', content: answer))

      assistant = Rasti::AI::OpenAI::Assistant.new state: state

      response = assistant.call question

      expected_assistant_message = {
        role: Rasti::AI::OpenAI::Roles::ASSISTANT,
        content: answer
      }

      assert_equal answer, response
      assert_equal 3, state.messages.count
      assert_equal expected_assistant_message, state.messages.last
    end

    it 'Model' do
      model = SecureRandom.uuid

      stub_open_ai_chat_completions question: question, answer: answer, model: model

      assistant = Rasti::AI::OpenAI::Assistant.new model: model

      response = assistant.call question

      assert_equal answer, response
    end

  end

  describe 'Tools' do

    class GoalsByPlayer
      def self.form
        Rasti::Form[player: Rasti::Types::String, team: Rasti::Types::String]
      end

      def call(params={})
        '672'
      end
    end

    let(:client) { Minitest::Mock.new }

    let(:tool_response) do
      read_json_resource(
        'open_ai/tool_response.json',
        name: 'goals_by_player',
        arguments: {
          player: 'Lionel Messi',
          team: 'Barcelona'
        }
      )
    end

    let(:tool_result) { '672' }

    let(:error_message) { 'There was an error using a tool' }

    def basic_response(content)
      read_json_resource(
        'open_ai/basic_response.json',
        content: content
      )
    end

    def stub_client_request(role:, content:, response:, tools:[])
      client.expect :chat_completions, response do |params|
        last_message = params[:messages].last
        last_message[:role] == role &&
          last_message[:content] == content &&
          params[:tools] == tools.map { |t| Rasti::AI::OpenAI::ToolSerializer.serialize t.class }
      end
    end

    it 'Call funcion' do
      tool = GoalsByPlayer.new

      stub_client_request role: Rasti::AI::OpenAI::Roles::USER,
                          content: question,
                          tools: [tool],
                          response: tool_response

      stub_client_request role: Rasti::AI::OpenAI::Roles::TOOL,
                          content: tool_result,
                          tools: [tool],
                          response: basic_response(answer)

      assistant = Rasti::AI::OpenAI::Assistant.new client: client, tools: [tool]

      response = assistant.call question

      assert_equal answer, response

      client.verify
    end

    it 'Tool failure' do
      tool = GoalsByPlayer.new
      tool.define_singleton_method :call do |*args|
        raise 'Broken tool'
      end

      stub_client_request role: Rasti::AI::OpenAI::Roles::USER,
                          content: question,
                          tools: [tool],
                          response: tool_response

      stub_client_request role: Rasti::AI::OpenAI::Roles::TOOL,
                          content: 'Error: Broken tool',
                          tools: [tool],
                          response: basic_response(error_message)

      assistant = Rasti::AI::OpenAI::Assistant.new client: client, tools: [tool]

      response = assistant.call question

      assert_equal error_message, response

      client.verify
    end

    it 'Undefined tool' do
      stub_client_request role: Rasti::AI::OpenAI::Roles::USER,
                          content: question,
                          response: tool_response

      stub_client_request role: Rasti::AI::OpenAI::Roles::TOOL,
                          content: 'Error: Undefined tool goals_by_player',
                          response: basic_response(error_message)

      assistant = Rasti::AI::OpenAI::Assistant.new client: client, tools: []

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

      assistant = Rasti::AI::OpenAI::Assistant.new client: client, tools: [tool]

      5.times do
        stub_client_request role: Rasti::AI::OpenAI::Roles::USER,
                            content: question,
                            tools: [tool],
                            response: tool_response

        stub_client_request role: Rasti::AI::OpenAI::Roles::TOOL,
                            content: tool_result,
                            tools: [tool],
                            response: basic_response(answer)

        response = assistant.call question

        assert_equal answer, response
      end

      client.verify
    end

    it 'Custom logger' do
      log_output = StringIO.new
      logger = Logger.new log_output

      tool = GoalsByPlayer.new

      stub_client_request role: Rasti::AI::OpenAI::Roles::USER,
                          content: question,
                          tools: [tool],
                          response: tool_response

      stub_client_request role: Rasti::AI::OpenAI::Roles::TOOL,
                          content: tool_result,
                          tools: [tool],
                          response: basic_response(answer)

      assistant = Rasti::AI::OpenAI::Assistant.new client: client, tools: [tool], logger: logger

      response = assistant.call question

      assert_equal answer, response

      refute_empty log_output.string

      client.verify
    end

  end

end