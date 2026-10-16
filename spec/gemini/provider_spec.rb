require 'minitest_helper'

describe Rasti::AI::Gemini::Provider do

  let(:provider) { Rasti::AI.provider :gemini }

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  def api_url(model:nil)
    "https://generativelanguage.googleapis.com/v1beta/models/#{model || Rasti::AI.gemini_default_model}:generateContent?key=#{Rasti::AI.gemini_api_key}"
  end

  def stub_generate_content(request_body)
    stub_request(:post, api_url)
      .with(body: JSON.dump(request_body))
      .to_return(body: read_resource('gemini/basic_response.json', content: answer))
  end

  it 'Name, model and classes' do
    assert_equal :gemini, provider.name
    assert_equal Rasti::AI.gemini_default_model, provider.model
    assert_instance_of Rasti::AI::Gemini::Client, provider.build_client
    assert_instance_of Rasti::AI::Gemini::Assistant, provider.create_assistant
  end

  it 'Generate text' do
    stub_generate_content contents: [
      {
        role: 'user',
        parts: [{text: question}]
      }
    ]

    result = provider.generate_text prompt: question

    assert_equal answer, result.content
    assert_equal 'gemini', result.usage.provider
    assert_equal 'gemini-test', result.raw['modelVersion']
  end

  it 'Generate text with generic roles and system' do
    stub_generate_content contents: [
                            {
                              role: 'user',
                              parts: [{text: 'who is the best player'}]
                            },
                            {
                              role: 'model',
                              parts: [{text: 'Lionel Messi'}]
                            },
                            {
                              role: 'user',
                              parts: [{text: question}]
                            }
                          ],
                          system_instruction: {
                            parts: [{text: 'Act as sports journalist'}]
                          }

    messages = [
      {role: Rasti::AI::Roles::SYSTEM, content: 'Act as sports journalist'},
      {role: Rasti::AI::Roles::USER, content: 'who is the best player'},
      {role: Rasti::AI::Roles::ASSISTANT, content: 'Lionel Messi'},
      {role: Rasti::AI::Roles::USER, content: question}
    ]

    assert_equal answer, provider.generate_text(messages: messages).content
  end

  it 'Generate text with json schema and thinking' do
    json_schema = {type: 'object', properties: {player: {type: 'string'}}}

    stub_generate_content contents: [
                            {
                              role: 'user',
                              parts: [{text: question}]
                            }
                          ],
                          generation_config: {
                            thinking_config: {thinking_budget: 8_192},
                            response_mime_type: 'application/json',
                            response_schema: json_schema
                          }

    assert_equal answer, provider.generate_text(prompt: question, json_schema: json_schema, thinking: 'medium').content
  end

  it 'Generate text with thinking none' do
    stub_generate_content contents: [
                            {
                              role: 'user',
                              parts: [{text: question}]
                            }
                          ],
                          generation_config: {
                            thinking_config: {thinking_budget: 0}
                          }

    assert_equal answer, provider.generate_text(prompt: question, thinking: 'none').content
  end

end
