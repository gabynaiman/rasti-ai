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
assistant = Rasti::AI::OpenAI::Assistant.new
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

assistant = Rasti::AI::OpenAI::Assistant.new tools: tools

assistant.call 'what time is it' # => 'The current time is 3:03 PM on April 28, 2025.'

assistant.call 'what is the weather in Buenos Aires' # => 'In Buenos Aires it is 15 degrees'
```

#### Context and state
```ruby
state = Rasti::AI::OpenAI::AssistantState.new context: 'Act as sports journalist'

assistant = Rasti::AI::OpenAI::Assistant.new state: state

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

### MCP (Model Context Protocol)

Rasti::AI includes support for the Model Context Protocol, allowing you to create MCP servers and clients for tool communication.

#### MCP Server

The MCP Server acts as a Rack middleware that exposes registered tools through a JSON-RPC 2.0 interface.

##### Configuration

```ruby
Rasti::AI::MCP::Server.configure do |config|
  config.server_name = 'My MCP Server'
  config.server_version = '1.0.0'
  config.relative_path = '/mcp' # Default endpoint path
end
```

##### Registering Tools

Tools must inherit from `Rasti::AI::Tool` and can be registered with the server:

```ruby
class HelloWorldTool < Rasti::AI::Tool
  def self.description
    'Returns a hello world message'
  end

  def execute(form)
    {text: 'Hello world'}
  end
end

class SumTool < Rasti::AI::Tool
  class Form < Rasti::Form
    attribute :number_a, Rasti::Types::Float
    attribute :number_b, Rasti::Types::Float
  end

  def execute(form)
    {result: form.number_a + form.number_b}
  end
end

# Register tools
Rasti::AI::MCP::Server.register_tool HelloWorldTool.new
Rasti::AI::MCP::Server.register_tool SumTool.new
```

##### Using as Rack Middleware

```ruby
# In your config.ru
require 'rasti/ai'

# Register your tools
Rasti::AI::MCP::Server.register_tool HelloWorldTool.new
Rasti::AI::MCP::Server.register_tool SumTool.new

# Use as middleware
use Rasti::AI::MCP::Server

run YourApp
```

The server will handle POST requests to the configured path (`/mcp` by default) and pass all other requests to your application.

##### Supported MCP Methods

- `initialize` - Returns protocol version and server capabilities
- `tools/list` - Returns all registered tools with their schemas
- `tools/call` - Executes a specific tool with provided arguments

#### MCP Client

The MCP Client allows you to communicate with MCP servers.

##### Basic Usage

```ruby
# Create a client
client = Rasti::AI::MCP::Client.new(
  url: 'https://mcp.server.ai/mcp'
)

# List available tools
tools = client.list_tools
# => [
#      { "name" => "hello_world_tool", "description" => "Hello World", ... },
#      { "name" => "sum_tool", "description" => "Sum two numbers", ... }
#    ]

# Call a tool
result = client.call_tool 'sum_tool', number_a: 5, number_b: 3
# => '{"type":"text","text":"{\"result\":8.0}"}'

result = client.call_tool 'hello_world_tool'
# => '{"type":"text","text":"{\"text\":\"Hello world\"}"}'
```

##### Restricting Available Tools

You can restrict which tools the client can access:

```ruby
client = Rasti::AI::MCP::Client.new(
  url: 'https://mcp.server.ai/mcp',
  allowed_tools: ['sum_tool', 'multiply_tool']
)

# Only returns allowed tools
tools = client.list_tools
# => [{ "name" => "sum_tool", ... }]

# Calling a non-allowed tool raises an error
client.call_tool 'hello_world_tool'
# => RuntimeError: Invalid tool: hello_world_tool
```

##### Custom Logger

```ruby
client = Rasti::AI::MCP::Client.new(
  url: 'https://mcp.server.ai/mcp',
  logger: Logger.new(STDOUT)
)
```

##### Integration with OpenAI Assistant

You can use MCP clients as tools for the OpenAI Assistant:

```ruby
# Create an MCP client
mcp_client = Rasti::AI::MCP::Client.new(
  url: 'https://mcp.server.ai/mcp'
)

# Use it with the assistant
assistant = Rasti::AI::OpenAI::Assistant.new(
  mcp_servers: {
    my_mcp: mcp_client
  }
)

# The assistant can now call tools from the MCP server
assistant.call 'What is 5 plus 3?'
# The assistant will use the sum_tool from the MCP server
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gabynaiman/rasti-ai.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).