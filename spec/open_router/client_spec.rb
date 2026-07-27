require 'minitest_helper'

describe Rasti::AI::OpenRouter::Client do

  let(:api_url) { 'https://openrouter.ai/api/v1/chat/completions' }

  let(:question) { 'who is Messi?' }

  let(:answer) { 'Lionel Messi is the best player ever' }

  def user_message(content)
    {role: Rasti::AI::OpenRouter::Roles::USER, content: content}
  end

  it 'Basic message with correct base URL and auth header' do
    stub_request(:post, api_url)
      .with(
        headers: {'Authorization' => "Bearer #{Rasti::AI.openrouter_api_key}"},
        body: read_resource('open_ai/basic_request.json', model: Rasti::AI.openrouter_default_model, prompt: question)
      )
      .to_return(body: read_resource('open_ai/basic_response.json', content: answer))

    client = Rasti::AI::OpenRouter::Client.new

    response = client.chat_completions messages: [user_message(question)]

    assert_equal answer, response.dig('choices', 0, 'message', 'content')
  end

  it 'Usage tracking with provider name' do
    stub_request(:post, api_url)
      .to_return(body: read_resource('open_ai/basic_response.json', content: answer))

    tracked = []
    tracker = ->(usage) { tracked << usage }

    client = Rasti::AI::OpenRouter::Client.new usage_tracker: tracker

    client.chat_completions messages: [user_message(question)]

    assert_equal 1, tracked.count
    assert_instance_of Rasti::AI::Usage, tracked[0]
    assert_equal 'open_router', tracked[0].provider
  end

  it 'Custom model' do
    model = SecureRandom.uuid

    stub_request(:post, api_url)
      .with(body: read_resource('open_ai/basic_request.json', model: model, prompt: question))
      .to_return(body: read_resource('open_ai/basic_response.json', content: answer))

    client = Rasti::AI::OpenRouter::Client.new

    response = client.chat_completions messages: [user_message(question)], model: model

    assert_equal answer, response.dig('choices', 0, 'message', 'content')
  end

end
