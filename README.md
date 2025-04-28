# Rasti::AI

[![Gem Version](https://badge.fury.io/rb/rasti-ai.svg)](https://rubygems.org/gems/rasti-ai)
[![CI](https://github.com/gabynaiman/rasti-ai/actions/workflows/ci.yml/badge.svg)](https://github.com/gabynaiman/rasti-ai/actions/workflows/ci.yml)

AI for apps

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rasti-ai'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rasti-ai

## Usage

### Configuration
```ruby
Rasti::AI.configure do |config|
  config.logger = Logger.new 'log/development.log'
  config.openai_api_key = 'abcd12345' # Default ENV['OPENAI_API_KEY']
  config.openai_default_model = 'gpt-4o-mini' # Default ENV['OPENAI_DEFAULT_MODEL']
end
```

### Open AI

#### Assistant
```ruby
assistant = Rasti::AI::Providers::OpenAI::Assistant.new
assistant.call 'who is the best player' # => 'The best player is Lionel Messi'
```

#### Tools
```ruby
class GetCurrentTime
  def call(params={})
    Time.now.iso8601
  end
end

class GetCurrentWeather
  def self.form
    Rasti::Form[location: Rasti::Types::String]
  end

  def call(params={})
    response = HTTP.get "https://api.wheater.com/?location=#{params['location']}"
    response.body.to_s
  end
end

tools = [
  GetCurrentTime.new,
  GetCurrentWeather.new
]

assistant = Rasti::AI::Providers::OpenAI::Assistant.new tools: tools

assistant.call 'what time is it' # => 'The current time is 3:03 PM on April 28, 2025.'

assistant.call 'what is the weather in Buenos Aires' # => 'In Buenos Aires it is 15 degrees'
```

#### Context and state
```ruby
state = Rasti::AI::Providers::OpenAI::AssistantState.new context: 'Act as sports journalist'

assistant = Rasti::AI::Providers::OpenAI::Assistant.new state: state

assistant.call 'who is the best player'

state.messages
# [
#   {
#     role: 'system',
#     content: 'Act as sports journalist'
#   },
#   {
#     role: 'user',
#     content: 'who is the best player'
#   },
#   {
#     role: 'assistant',
#     content: 'The best player is Lionel Messi'
#   }
# ]
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gabynaiman/rasti-ai.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

