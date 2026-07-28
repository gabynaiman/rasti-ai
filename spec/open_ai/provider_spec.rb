require 'minitest_helper'

describe Rasti::AI::OpenAI::Provider do

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  def stub_chat_completions(url, request_body)
    stub_request(:post, url)
      .with(body: JSON.dump(request_body))
      .to_return(body: read_resource('open_ai/basic_response.json', content: answer))
  end

  def basic_body(model)
    {
      model: model,
      messages: [
        {
          role: 'user',
          content: question
        }
      ],
      tools: [],
      tool_choice: 'none'
    }
  end

  it 'Name, model and classes' do
    provider = Rasti::AI.provider :open_ai

    assert_equal :open_ai, provider.name
    assert_equal Rasti::AI.openai_default_model, provider.model
    assert_instance_of Rasti::AI::OpenAI::Client, provider.build_client
    assert_instance_of Rasti::AI::OpenAI::Assistant, provider.create_assistant
  end

  it 'Generate text' do
    stub_chat_completions 'https://api.openai.com/v1/chat/completions', basic_body(Rasti::AI.openai_default_model)

    result = Rasti::AI.provider(:open_ai).generate_text prompt: question

    assert_equal answer, result.content
    assert_equal 'open_ai', result.usage.provider
  end

  it 'Generate text with json schema and thinking' do
    json_schema = {player: 'string'}

    body = basic_body(Rasti::AI.openai_default_model).merge(
      response_format: {
        type: 'json_schema',
        json_schema: json_schema
      },
      reasoning_effort: 'low'
    )

    stub_chat_completions 'https://api.openai.com/v1/chat/completions', body

    result = Rasti::AI.provider(:open_ai).generate_text prompt: question, json_schema: json_schema, thinking: 'low'

    assert_equal answer, result.content
  end

  describe 'OpenAI compatible providers' do

    it 'OpenRouter' do
      provider = Rasti::AI.provider :open_router

      assert_equal :open_router, provider.name
      assert_equal Rasti::AI.openrouter_default_model, provider.model
      assert_instance_of Rasti::AI::OpenRouter::Client, provider.build_client
      assert_instance_of Rasti::AI::OpenRouter::Assistant, provider.create_assistant

      stub_chat_completions 'https://openrouter.ai/api/v1/chat/completions', basic_body(Rasti::AI.openrouter_default_model)

      result = provider.generate_text prompt: question

      assert_equal answer, result.content
      assert_equal 'open_router', result.usage.provider
    end

    it 'Huawei MaaS' do
      provider = Rasti::AI.provider :huawei_maas

      assert_equal :huawei_maas, provider.name
      assert_equal Rasti::AI.huawei_maas_default_model, provider.model
      assert_instance_of Rasti::AI::HuaweiMaaS::Client, provider.build_client
      assert_instance_of Rasti::AI::HuaweiMaaS::Assistant, provider.create_assistant

      stub_chat_completions 'https://api-ap-southeast-1.modelarts-maas.com/v2/chat/completions', basic_body(Rasti::AI.huawei_maas_default_model)

      result = provider.generate_text prompt: question

      assert_equal answer, result.content
      assert_equal 'huawei_maas', result.usage.provider
    end

  end

end
