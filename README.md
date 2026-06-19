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

  # HTTP settings
  config.http_connect_timeout = 60 # Default 60 seconds
  config.http_read_timeout = 60    # Default 60 seconds
  config.http_max_retries = 3      # Default 3 retries

  # OpenAI
  config.openai_api_key = 'abcd12345' # Default ENV['OPENAI_API_KEY']
  config.openai_default_model = 'gpt-4o-mini' # Default ENV['OPENAI_DEFAULT_MODEL']

  # Gemini
  config.gemini_api_key = 'AIza12345' # Default ENV['GEMINI_API_KEY']
  config.gemini_default_model = 'gemini-2.0-flash' # Default ENV['GEMINI_DEFAULT_MODEL']

  # Anthropic
  config.anthropic_api_key = 'sk-ant-12345' # Default ENV['ANTHROPIC_API_KEY']
  config.anthropic_default_model = 'claude-opus-4-5' # Default ENV['ANTHROPIC_DEFAULT_MODEL']

  # Usage tracking
  config.usage_tracker = ->(usage) { puts "#{usage.provider}: #{usage.input_tokens} in / #{usage.output_tokens} out" }
end
```

### Supported providers

- **OpenAI** - `Rasti::AI::OpenAI::Assistant`
- **Gemini** - `Rasti::AI::Gemini::Assistant`
- **Anthropic** - `Rasti::AI::Anthropic::Assistant`

All providers share the same interface. The examples below use OpenAI, but apply equally to Gemini or Anthropic by replacing `OpenAI` with the provider name.

### Assistant

```ruby
assistant = Rasti::AI::OpenAI::Assistant.new
assistant.call 'who is the best player' # => 'The best player is Lionel Messi'
```

### Tools

Tools can be simple classes or inherit from `Rasti::AI::Tool`. Both approaches work with any provider.

#### Simple tools
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
    "The wheather in #{params['location']} is sunny"
  end
end
```

#### Tools inheriting from Rasti::AI::Tool
```ruby
class SumTool < Rasti::AI::Tool
  class Form < Rasti::Form
    attribute :number_a, Rasti::Types::Float, required: true, description: 'First number'
    attribute :number_b, Rasti::Types::Float, required: true, description: 'Second number'
  end

  def self.description
    'Sum two numbers'
  end

  def execute(form)
    {result: form.number_a + form.number_b}
  end
end
```

Supported form attribute types:
- `Rasti::Types::String` → `string`
- `Rasti::Types::Integer` → `integer`
- `Rasti::Types::Float` → `number`
- `Rasti::Types::Boolean` → `boolean`
- `Rasti::Types::Time` → `string (date)`
- `Rasti::Types::Enum[:a, :b]` → `string (enum)`
- `Rasti::Types::Array[Type]` → `array`
- `Rasti::Types::Model[FormClass]` → nested `object`
- `Rasti::Types::Hash` → `object`
- Custom types registered via `Rasti::Model::Schema.register_type_serializer` or implementing `to_schema` are picked up automatically
- Unknown types → no constraints (empty schema, no crash)

#### Using tools with an assistant
```ruby
tools = [
  GetCurrentTime.new,
  GetCurrentWeather.new
]

assistant = Rasti::AI::OpenAI::Assistant.new tools: tools

assistant.call 'what time is it' # => 'The current time is 3:03 PM on April 28, 2025.'

assistant.call 'what is the weather in Buenos Aires' # => 'In Buenos Aires it is 15 degrees'
```

### Context and state
```ruby
state = Rasti::AI::AssistantState.new context: 'Act as sports journalist'

assistant = Rasti::AI::OpenAI::Assistant.new state: state

assistant.call 'who is the best player'

state.context  # => 'Act as sports journalist'
state.messages # Array of provider-specific message hashes
```

The state keeps the conversation history, enabling multi-turn interactions. It also caches tool call results to avoid duplicate executions.

### Structured responses (JSON Schema)
```ruby
assistant = Rasti::AI::OpenAI::Assistant.new json_schema: {
  player: 'string',
  sport: 'string'
}

response = assistant.call 'who is the best player'
JSON.parse response # => {"player" => "Lionel Messi", "sport" => "Football"}
```

### Custom model and client
```ruby
# Override model
assistant = Rasti::AI::OpenAI::Assistant.new model: 'gpt-4o'

# Custom client with per-client HTTP settings
client = Rasti::AI::OpenAI::Client.new(
  http_connect_timeout: 120,
  http_read_timeout: 120,
  http_max_retries: 5
)

assistant = Rasti::AI::OpenAI::Assistant.new client: client

# Anthropic client
client = Rasti::AI::Anthropic::Client.new(
  http_connect_timeout: 120,
  http_read_timeout: 300  # Claude can be slow on long responses
)

assistant = Rasti::AI::Anthropic::Assistant.new client: client
```

### Thinking / extended reasoning

Some providers support extended reasoning ("thinking") to improve accuracy on complex tasks. Pass `thinking:` with a level of `'low'`, `'medium'`, or `'high'` when creating an assistant:

```ruby
assistant = Rasti::AI::Anthropic::Assistant.new thinking: 'high'
assistant.call 'Solve this step by step: ...'
```

The level controls how much computation the model can spend reasoning before responding. Higher levels may improve answer quality at the cost of more tokens and latency. Not all models support thinking — check your provider's documentation.

### Usage tracking

Track token consumption across API calls (including tool calls):

```ruby
tracked_usage = []
tracker = ->(usage) { tracked_usage << usage }

client = Rasti::AI::OpenAI::Client.new usage_tracker: tracker
assistant = Rasti::AI::OpenAI::Assistant.new client: client
assistant.call 'who is the best player'

usage = tracked_usage.first
usage.provider          # => :open_ai
usage.model             # => 'gpt-4o-mini'
usage.input_tokens      # => 150
usage.output_tokens     # => 42
usage.cached_tokens     # => 0
usage.reasoning_tokens  # => 0
usage.raw               # => Raw usage payload from provider
```

The tracker can also be configured globally:

```ruby
Rasti::AI.configure do |config|
  config.usage_tracker = ->(usage) { MyMetrics.track(usage) }
end
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

##### Authentication

Use the `authenticate` block to control access to the MCP endpoint. The block receives the current `Rack::Request` and must return a truthy value to allow the request or a falsy value to reject it.

```ruby
Rasti::AI::MCP::Server.configure do |config|
  config.authenticate do |request|
    request.env['HTTP_AUTHORIZATION'] == "Bearer #{ENV['MCP_TOKEN']}"
  end
end
```

When authentication fails the server returns HTTP 401 with a JSON-RPC error body. The check runs before the request body is read, so it covers all MCP methods including `initialize`.

The `authenticate` and `load_tools` blocks are independent — when authentication fails `load_tools` is never called.

##### Registering Tools

Tools are registered per-request via a `load_tools` block. The block receives a `ToolsRegistry` and the current `Rack::Request`, enabling context-aware tool instantiation (e.g. based on the authenticated user).

```ruby
Rasti::AI::MCP::Server.configure do |config|
  config.load_tools do |tools_registry, request|
    user = User.find(request.session[:user_id])

    # Form A: Rasti::AI::Tool instance — name, description and schema derived from the class
    tools_registry.register tool: MyTool.new(user)

    # Form B: tool instance with a custom name
    tools_registry.register name: 'search', tool: SearchTool.new(user)

    # Form C: tool instance with description or schema overrides
    tools_registry.register(
      tool: MyTool.new(user),
      description: 'Contextual description for the LLM'
    )

    # Form D: existing Form class + block — schema from the Form, execution in the block
    tools_registry.register(name: 'sum', description: 'Sum two numbers', form: SumTool::Form) do |args|
      SumTool.new.call(args)
    end

    # Form E: fully inline — raw JSON Schema, no class required
    tools_registry.register(
      name: 'report',
      description: 'Generate a report',
      input_schema: {
        type: 'object',
        properties: {
          title: {type: 'string'},
          filters: {
            type: 'object',
            properties: {
              category: {type: 'string', enum: ['sales', 'ops']},
              date_range: {
                type: 'object',
                properties: {
                  from: {type: 'string', format: 'date'},
                  to: {type: 'string', format: 'date'}
                },
                required: ['from', 'to']
              }
            }
          }
        },
        required: ['title']
      }
    ) do |args|
      user.generate_report(args['title'], args['filters'])
    end
  end
end
```

`tools_registry.register` accepts all keyword arguments as optional and combines them according to these precedence rules:

| Parameter | Purpose | Precedence |
|---|---|---|
| `name:` | Tool identifier | Explicit > derived from `tool.class` |
| `description:` | Description shown to the LLM | Explicit > `tool.class.description` |
| `input_schema:` | Raw JSON Schema hash for parameters | Explicit > `form:` > `tool.class.form` |
| `form:` | `Rasti::Form` subclass for schema | Used when no `input_schema:` |
| `tool:` | `Rasti::AI::Tool` instance | Provides defaults + executor |
| block | Executor called with args hash | Block > `tool.call` |

Block executors receive the arguments as a `Hash` with string keys and must return a `String`.

##### Using as Rack Middleware

```ruby
# In your config.ru
require 'rasti/ai'

Rasti::AI::MCP::Server.configure do |config|
  config.load_tools do |tools_registry, request|
    user = User.find(request.session[:user_id])
    tools_registry.register tool: MyTool.new(user)
    tools_registry.register tool: OtherTool.new(user)
  end
end

use Rasti::AI::MCP::Server

run YourApp
```

The server handles POST requests to the configured path (`/mcp` by default) and forwards all other requests to the application. The `load_tools` block runs on every request, so tools are always fresh and scoped to the current request context.

##### Supported MCP Methods

- `initialize` - Returns protocol version and server capabilities
- `tools/list` - Returns all registered tools with their schemas
- `tools/call` - Executes a specific tool with provided arguments

#### MCP Client

The MCP Client allows you to communicate with MCP servers.

##### Basic Usage

```ruby
client = Rasti::AI::MCP::Client.new url: 'https://mcp.server.ai/mcp'


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

##### Integration with Assistants

You can use MCP clients as tools for any assistant:

```ruby
mcp_client = Rasti::AI::MCP::Client.new url: 'https://mcp.server.ai/mcp'


assistant = Rasti::AI::OpenAI::Assistant.new(
  mcp_servers: {my_mcp: mcp_client}
)

# The assistant can now call tools from the MCP server
assistant.call 'What is 5 plus 3?'
```

## Try it out

The gem includes interactive chat tasks wired to the [Pipeworx](https://pipeworx.io) public weather MCP server (no auth required):

```bash
OPENAI_API_KEY=sk-...    rake assistant:openai
GEMINI_API_KEY=AIza...   rake assistant:gemini
ANTHROPIC_API_KEY=sk-... rake assistant:anthropic
```

Type your message and press Enter. Type `exit` or `Ctrl+C` to quit.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gabynaiman/rasti-ai.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
