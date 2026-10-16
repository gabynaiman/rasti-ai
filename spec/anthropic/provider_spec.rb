require 'minitest_helper'

describe Rasti::AI::Anthropic::Provider do

  let(:provider) { Rasti::AI.provider :anthropic }

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  def stub_messages(request_body, response_body=nil)
    stub_request(:post, 'https://api.anthropic.com/v1/messages')
      .with(headers: {'x-api-key' => Rasti::AI.anthropic_api_key}, body: JSON.dump(request_body))
      .to_return(body: response_body || read_resource('anthropic/basic_response.json', content: answer))
  end

  it 'Name, model and classes' do
    assert_equal :anthropic, provider.name
    assert_equal Rasti::AI.anthropic_default_model, provider.model
    assert_instance_of Rasti::AI::Anthropic::Client, provider.build_client
    assert_instance_of Rasti::AI::Anthropic::Assistant, provider.create_assistant
  end

  it 'Generate text' do
    stub_messages model: Rasti::AI.anthropic_default_model,
                  max_tokens: 4096,
                  messages: [
                    {
                      role: 'user',
                      content: question
                    }
                  ]

    result = provider.generate_text prompt: question

    assert_equal answer, result.content
    assert_equal 'anthropic', result.usage.provider
    assert_equal 'end_turn', result.raw['stop_reason']
  end

  it 'Generate text with system, thinking and model override' do
    stub_messages model: 'claude-sonnet-4-5',
                  max_tokens: 4096,
                  messages: [
                    {
                      role: 'user',
                      content: question
                    }
                  ],
                  thinking: {type: 'enabled', budget_tokens: 16_000},
                  system: 'Act as sports journalist'

    result = provider.generate_text prompt: question,
                                    model: 'claude-sonnet-4-5',
                                    system: 'Act as sports journalist',
                                    thinking: 'high'

    assert_equal answer, result.content
  end

  it 'Generate text with thinking none' do
    stub_messages model: Rasti::AI.anthropic_default_model,
                  max_tokens: 4096,
                  messages: [
                    {
                      role: 'user',
                      content: question
                    }
                  ]

    result = provider.generate_text prompt: question, thinking: 'none'

    assert_equal answer, result.content
  end

  it 'Generate text with json schema' do
    json_schema = {player: 'string'}

    structured_response = {
      'content' => [
        {
          'type' => 'tool_use',
          'id' => 'toolu_1',
          'name' => 'structured_output',
          'input' => {'player' => 'Lionel Messi'}
        }
      ],
      'stop_reason' => 'tool_use'
    }

    stub_messages(
      {
        model: Rasti::AI.anthropic_default_model,
        max_tokens: 4096,
        messages: [
          {
            role: 'user',
            content: question
          }
        ],
        tools: [
          {
            name: 'structured_output',
            description: 'Return the structured response',
            input_schema: {
              type: 'object',
              properties: json_schema
            }
          }
        ],
        tool_choice: {type: 'tool', name: 'structured_output'}
      },
      JSON.dump(structured_response)
    )

    result = provider.generate_text prompt: question, json_schema: json_schema

    assert_equal '{"player":"Lionel Messi"}', result.content
  end

end
