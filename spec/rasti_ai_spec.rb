require 'minitest_helper'

describe Rasti::AI do

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  def stub_open_ai(model:nil, prompt:nil, content:nil)
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .with(body: read_resource('open_ai/basic_request.json', model: model || Rasti::AI.openai_default_model, prompt: prompt || question))
      .to_return(body: read_resource('open_ai/basic_response.json', content: content || answer))
  end

  def with_default_provider(provider)
    previous = Rasti::AI.default_provider
    Rasti::AI.default_provider = provider
    yield
  ensure
    Rasti::AI.default_provider = previous
  end

  describe 'Create assistant' do

    it 'Provider' do
      assistant = Rasti::AI.create_assistant provider: :open_ai

      assert_instance_of Rasti::AI::OpenAI::Assistant, assistant
    end

    it 'Provider alias' do
      assistant = Rasti::AI.create_assistant provider: 'openai'

      assert_instance_of Rasti::AI::OpenAI::Assistant, assistant
    end

    it 'Provider and model' do
      assistant = Rasti::AI.create_assistant provider: :anthropic, model: 'claude-sonnet-4-5'

      assert_instance_of Rasti::AI::Anthropic::Assistant, assistant
      assert_equal 'claude-sonnet-4-5', assistant.model
    end

    it 'Provider and model as single string' do
      assistant = Rasti::AI.create_assistant model: 'gemini:gemini-2.0-flash'

      assert_instance_of Rasti::AI::Gemini::Assistant, assistant
      assert_equal 'gemini-2.0-flash', assistant.model
    end

    it 'Default provider from config' do
      with_default_provider :anthropic do
        assistant = Rasti::AI.create_assistant

        assert_instance_of Rasti::AI::Anthropic::Assistant, assistant
      end
    end

    it 'Explicit provider takes precedence over config' do
      with_default_provider :anthropic do
        assistant = Rasti::AI.create_assistant provider: :gemini

        assert_instance_of Rasti::AI::Gemini::Assistant, assistant
      end
    end

    it 'Undefined provider' do
      with_default_provider nil do
        error = assert_raises ArgumentError do
          Rasti::AI.create_assistant
        end

        assert_match /\AUndefined provider/, error.message
      end
    end

    it 'Unknown provider' do
      assert_raises Rasti::AI::Errors::UnknownProvider do
        Rasti::AI.create_assistant provider: :invalid
      end
    end

    it 'Thinking, tools and json schema' do
      assistant = Rasti::AI.create_assistant provider: :open_ai,
                                             thinking: 'high',
                                             tools: [GoalsByPlayer.new],
                                             json_schema: {player: 'string'}

      assert_equal 'high', assistant.thinking
    end

    it 'System' do
      assistant = Rasti::AI.create_assistant provider: :open_ai, system: 'Act as sports journalist'

      assert_equal 'Act as sports journalist', assistant.state.context
    end

    it 'State' do
      state = Rasti::AI::AssistantState.new context: 'Act as sports journalist'

      assistant = Rasti::AI.create_assistant provider: :open_ai, state: state

      assert_same state, assistant.state
    end

    it 'State and system are mutually exclusive' do
      error = assert_raises ArgumentError do
        Rasti::AI.create_assistant provider: :open_ai, state: Rasti::AI::AssistantState.new, system: 'Act as sports journalist'
      end

      assert_equal 'Use state or system, not both', error.message
    end

    it 'Custom client' do
      client = Rasti::AI::OpenAI::Client.new

      assistant = Rasti::AI.create_assistant provider: :open_ai, client: client

      stub_open_ai

      assert_equal answer, assistant.call(question)
    end

    it 'Client options' do
      stub_open_ai

      tracked_usage = []

      assistant = Rasti::AI.create_assistant provider: :open_ai,
                                             api_key: 'custom_api_key',
                                             usage_tracker: ->(usage) { tracked_usage << usage },
                                             http_read_timeout: 120,
                                             http_max_retries: 5

      assistant.call question

      assert_requested :post, 'https://api.openai.com/v1/chat/completions',
                       headers: {'Authorization' => 'Bearer custom_api_key'}

      assert_equal 1, tracked_usage.count
      assert_equal 'open_ai', tracked_usage.first.provider
    end

  end

  describe 'Provider' do

    it 'Build from name' do
      provider = Rasti::AI.provider :open_ai

      assert_instance_of Rasti::AI::OpenAI::Provider, provider
      assert_equal :open_ai, provider.name
      assert_equal Rasti::AI.openai_default_model, provider.model
    end

    it 'Build from alias' do
      assert_instance_of Rasti::AI::OpenRouter::Provider, Rasti::AI.provider('openrouter')
      assert_instance_of Rasti::AI::HuaweiMaaS::Provider, Rasti::AI.provider(:huawei)
      assert_instance_of Rasti::AI::OpenAI::Provider, Rasti::AI.provider(:OpenAI)
    end

    it 'Build from provider and model as single string' do
      provider = Rasti::AI.provider model: 'anthropic:claude-sonnet-4-5'

      assert_instance_of Rasti::AI::Anthropic::Provider, provider
      assert_equal 'claude-sonnet-4-5', provider.model
    end

    it 'Names' do
      assert_equal [:open_ai, :gemini, :anthropic, :open_router, :huawei_maas], Rasti::AI::Provider.names
    end

    it 'Unknown provider' do
      error = assert_raises Rasti::AI::Errors::UnknownProvider do
        Rasti::AI.provider :invalid
      end

      assert_equal 'Unknown provider :invalid. Valid providers: open_ai, gemini, anthropic, open_router, huawei_maas', error.message
    end

    it 'Builds client and assistant of its own provider' do
      provider = Rasti::AI.provider :gemini

      assert_instance_of Rasti::AI::Gemini::Client, provider.build_client
      assert_instance_of Rasti::AI::Gemini::Assistant, provider.create_assistant
    end

    it 'Reusable instance' do
      provider = Rasti::AI.provider :open_ai, api_key: 'tenant_api_key'

      stub_open_ai

      provider.generate_text prompt: question

      assert_requested :post, 'https://api.openai.com/v1/chat/completions',
                       headers: {'Authorization' => 'Bearer tenant_api_key'}

      assert_instance_of Rasti::AI::OpenAI::Assistant, provider.create_assistant
    end

    it 'Invalid thinking level' do
      error = assert_raises ArgumentError do
        Rasti::AI.provider(:open_ai).generate_text prompt: question, thinking: 'invalid'
      end

      assert_equal "Invalid thinking level 'invalid'. Valid: none, low, medium, high", error.message
    end

  end

  describe 'Generate text' do

    it 'Provider' do
      stub_open_ai

      result = Rasti::AI.generate_text prompt: question, provider: :open_ai

      assert_instance_of Rasti::AI::Result, result
      assert_equal answer, result.content
      assert_equal 'open_ai', result.usage.provider
      assert_equal 27, result.usage.input_tokens
      assert_equal 229, result.usage.output_tokens
      assert_equal 'stop', result.raw['choices'][0]['finish_reason']
    end

    it 'Provider and model' do
      stub_open_ai model: 'gpt-4o'

      result = Rasti::AI.generate_text prompt: question, provider: :open_ai, model: 'gpt-4o'

      assert_equal answer, result.content
    end

    it 'Provider and model as single string' do
      stub_open_ai model: 'gpt-4o'

      result = Rasti::AI.generate_text prompt: question, model: 'open_ai:gpt-4o'

      assert_equal answer, result.content
    end

    it 'Default provider from config' do
      with_default_provider :open_ai do
        stub_open_ai

        assert_equal answer, Rasti::AI.generate_text(prompt: question).content
      end
    end

    it 'Messages with generic roles' do
      messages = [
        {role: Rasti::AI::Roles::USER, content: 'who is the best player'},
        {role: Rasti::AI::Roles::ASSISTANT, content: 'Lionel Messi'},
        {role: Rasti::AI::Roles::USER, content: question}
      ]

      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .with(body: read_resource('open_ai/conversation_request.json', model: Rasti::AI.openai_default_model, prompt: question))
        .to_return(body: read_resource('open_ai/basic_response.json', content: answer))

      result = Rasti::AI.generate_text messages: messages, provider: :open_ai

      assert_equal answer, result.content
    end

    it 'System message inside messages' do
      messages = [
        {role: Rasti::AI::Roles::SYSTEM, content: 'Act as sports journalist'},
        {role: Rasti::AI::Roles::USER, content: question}
      ]

      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .with(body: read_resource('open_ai/system_request.json', model: Rasti::AI.openai_default_model, system: 'Act as sports journalist', prompt: question))
        .to_return(body: read_resource('open_ai/basic_response.json', content: answer))

      assert_equal answer, Rasti::AI.generate_text(messages: messages, provider: :open_ai).content
    end

    it 'Prompt and messages are mutually exclusive' do
      error = assert_raises ArgumentError do
        Rasti::AI.generate_text prompt: question, messages: [], provider: :open_ai
      end

      assert_equal 'Use prompt or messages, not both', error.message
    end

    it 'Undefined prompt and messages' do
      error = assert_raises ArgumentError do
        Rasti::AI.generate_text provider: :open_ai
      end

      assert_equal 'Undefined prompt or messages', error.message
    end

    it 'System' do
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .with(body: read_resource('open_ai/system_request.json', model: Rasti::AI.openai_default_model, system: 'Act as sports journalist', prompt: question))
        .to_return(body: read_resource('open_ai/basic_response.json', content: answer))

      result = Rasti::AI.generate_text prompt: question,
                                       provider: :open_ai,
                                       system: 'Act as sports journalist'

      assert_equal answer, result.content
    end

    it 'Usage tracker' do
      stub_open_ai

      tracked_usage = []

      result = Rasti::AI.generate_text prompt: question,
                                       provider: :open_ai,
                                       usage_tracker: ->(usage) { tracked_usage << usage }

      assert_equal 1, tracked_usage.count
      assert_equal tracked_usage.first.to_h, result.usage.to_h
    end

  end

end
