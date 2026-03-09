require 'minitest_helper'

describe Rasti::AI::Gemini::Assistant do

  def api_url(model:nil)
    model ||= Rasti::AI.gemini_default_model
    "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{Rasti::AI.gemini_api_key}"
  end

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  def stub_gemini_generate_content(question:, answer:, model:nil, generation_config:nil)
    model ||= Rasti::AI.gemini_default_model

    body = read_json_resource('gemini/basic_request.json', prompt: question)
    body['generation_config'] = generation_config if generation_config

    stub_request(:post, api_url(model: model))
      .with(body: JSON.dump(body))
      .to_return(body: read_resource('gemini/basic_response.json', content: answer))
  end

  it 'Default' do
    stub_gemini_generate_content question: question, answer: answer

    assistant = Rasti::AI::Gemini::Assistant.new

    response = assistant.call question

    assert_equal answer, response
  end

  describe 'Customized' do

    it 'Client' do
      client_arguments = [
        {
          model: nil,
          tools: [],
          contents: [
            {
              role: Rasti::AI::Gemini::Roles::USER,
              parts: [{text: question}]
            }
          ],
          system_instruction: nil,
          generation_config: nil
        }
      ]

      client_response = read_json_resource 'gemini/basic_response.json', content: answer

      client = Minitest::Mock.new
      client.expect :generate_content, client_response, client_arguments

      assistant = Rasti::AI::Gemini::Assistant.new client: client

      response = assistant.call question

      assert_equal answer, response

      client.verify
    end

    it 'State' do
      context = 'Act as sports journalist'
      state = Rasti::AI::AssistantState.new context: context

      request_body = {
        contents: [
          {
            role: Rasti::AI::Gemini::Roles::USER,
            parts: [{text: question}]
          }
        ],
        system_instruction: {
          parts: [{text: context}]
        }
      }

      stub_request(:post, api_url)
        .with(body: JSON.dump(request_body))
        .to_return(body: read_resource('gemini/basic_response.json', content: answer))

      assistant = Rasti::AI::Gemini::Assistant.new state: state

      response = assistant.call question

      expected_assistant_message = {
        role: Rasti::AI::Gemini::Roles::MODEL,
        parts: [{text: answer}]
      }

      assert_equal answer, response
      assert_equal 2, state.messages.count
      assert_equal expected_assistant_message, state.messages.last
    end

    it 'Model' do
      model = SecureRandom.uuid

      stub_gemini_generate_content question: question, answer: answer, model: model

      assistant = Rasti::AI::Gemini::Assistant.new model: model

      response = assistant.call question

      assert_equal answer, response
    end

    it 'JSON Schema' do
      json_schema = {answer: 'Response answer'}
      json_answer = "{\\\"answer\\\": \\\"#{answer}\\\"}"

      generation_config = {
        response_mime_type: 'application/json',
        response_schema: json_schema
      }

      stub_gemini_generate_content question: question,
                                   answer: json_answer,
                                   generation_config: generation_config

      assistant = Rasti::AI::Gemini::Assistant.new json_schema: json_schema

      response = assistant.call question

      assert_equal answer, JSON.parse(response)['answer']
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
        'gemini/tool_response.json',
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
        'gemini/basic_response.json',
        content: content
      )
    end

    def stub_client_request(role:, content:nil, response:, tools:[], has_function_response:false)
      serialized_tools = tools.map do |tool|
        raw = Rasti::AI::ToolSerializer.serialize(tool.class)
        result = raw.dup
        result[:parameters] = result.delete(:inputSchema) if result.key?(:inputSchema)
        result
      end

      tool_payload = serialized_tools.empty? ? [] : [{function_declarations: serialized_tools}]

      client.expect :generate_content, response do |params|
        last_message = params[:contents].last

        if has_function_response
          part = last_message[:parts].first
          part.key?(:functionResponse) &&
            part[:functionResponse][:response][:content] == content &&
            params[:tools] == tool_payload
        else
          last_message[:role] == role &&
            last_message.dig(:parts, 0, :text) == content &&
            params[:tools] == tool_payload
        end
      end
    end

    it 'Call funcion' do
      tool = GoalsByPlayer.new

      stub_client_request role: Rasti::AI::Gemini::Roles::USER,
                          content: question,
                          tools: [tool],
                          response: tool_response

      stub_client_request role: Rasti::AI::Gemini::Roles::FUNCTION,
                          content: tool_result,
                          tools: [tool],
                          response: basic_response(answer),
                          has_function_response: true

      assistant = Rasti::AI::Gemini::Assistant.new client: client, tools: [tool]

      response = assistant.call question

      assert_equal answer, response

      client.verify
    end

    it 'Tool failure' do
      tool = GoalsByPlayer.new
      tool.define_singleton_method :call do |*args|
        raise 'Broken tool'
      end

      stub_client_request role: Rasti::AI::Gemini::Roles::USER,
                          content: question,
                          tools: [tool],
                          response: tool_response

      stub_client_request role: Rasti::AI::Gemini::Roles::FUNCTION,
                          content: 'Error: Broken tool',
                          tools: [tool],
                          response: basic_response(error_message),
                          has_function_response: true

      assistant = Rasti::AI::Gemini::Assistant.new client: client, tools: [tool]

      response = assistant.call question

      assert_equal error_message, response

      client.verify
    end

    it 'Undefined tool' do
      stub_client_request role: Rasti::AI::Gemini::Roles::USER,
                          content: question,
                          response: tool_response

      stub_client_request role: Rasti::AI::Gemini::Roles::FUNCTION,
                          content: 'Error: Undefined tool goals_by_player',
                          response: basic_response(error_message),
                          has_function_response: true

      assistant = Rasti::AI::Gemini::Assistant.new client: client, tools: []

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

      assistant = Rasti::AI::Gemini::Assistant.new client: client, tools: [tool]

      5.times do
        stub_client_request role: Rasti::AI::Gemini::Roles::USER,
                            content: question,
                            tools: [tool],
                            response: tool_response

        stub_client_request role: Rasti::AI::Gemini::Roles::FUNCTION,
                            content: tool_result,
                            tools: [tool],
                            response: basic_response(answer),
                            has_function_response: true

        response = assistant.call question

        assert_equal answer, response
      end

      client.verify
    end

    it 'Custom logger' do
      log_output = StringIO.new
      logger = Logger.new log_output

      tool = GoalsByPlayer.new

      stub_client_request role: Rasti::AI::Gemini::Roles::USER,
                          content: question,
                          tools: [tool],
                          response: tool_response

      stub_client_request role: Rasti::AI::Gemini::Roles::FUNCTION,
                          content: tool_result,
                          tools: [tool],
                          response: basic_response(answer),
                          has_function_response: true

      assistant = Rasti::AI::Gemini::Assistant.new client: client, tools: [tool], logger: logger

      response = assistant.call question

      assert_equal answer, response

      refute_empty log_output.string

      client.verify
    end

  end

end
