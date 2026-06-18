# AGENTS.md — Rasti::AI internals

Developer and agent reference. For usage examples see README.md.

## Architecture

### Template method pattern

`Rasti::AI::Client` and `Rasti::AI::Assistant` are abstract base classes. Provider-specific subclasses implement a fixed set of methods; all shared logic (HTTP retries, tool caching, the request/response loop) lives in the base.

#### Client — methods to implement

```ruby
def default_api_key          # reads from Rasti::AI config
def base_url                 # e.g. 'https://api.anthropic.com/v1'
def parse_usage(response)    # returns a Usage instance or nil
# optionally override:
def build_request(uri)       # super + add auth headers
def build_url(relative_url)  # super unless URL needs query params (e.g. Gemini key)
```

The base `post` method handles JSON serialization, logging, retries on network errors and 5xx, and calls `track_usage` after each successful response.

#### Assistant — methods to implement (12 total)

```ruby
def build_default_client           # Client.new
def build_user_message(prompt)     # {role: ..., content: prompt}
def build_assistant_message(content)
def build_assistant_tool_calls_message(response)
def build_tool_result_message(tool_call, name, result)
def request_completion             # calls client's API method
def parse_tool_calls(response)     # returns array; empty = no tool call
def parse_content(response)        # extracts text string
def finished?(response)            # true when model is done
def extract_tool_call_info(tool_call)  # returns [name, args_hash]
def wrap_tool_serialization(raw)   # adapts ToolSerializer output to provider format
def extract_tool_name(wrapped)     # string name from wrapped tool hash
```

The base `call` loop: add user message → request completion → if tool calls: execute each, add results, loop → else: return content.

#### Tool — optional base class

Simple tool classes only need a `.form` class method and a `#call(params={})` instance method.

Tools inheriting from `Rasti::AI::Tool` define a nested `Form` class and an `execute(form)` method. The base `call` wraps `execute` and JSON-serializes the result — so **`call_tool` in the assistant always receives a String**.

Tool names are derived automatically via `Inflecto.underscore(Inflecto.demodulize(class_name))` — e.g. `MyApp::GetWeatherTool` → `get_weather_tool`.


## Project structure

```
lib/
  rasti-ai.rb                  # entry point, just requires rasti/ai
  rasti/
    ai.rb                      # module definition, config, loads all files
    ai/
      assistant.rb             # abstract base class (template method pattern)
      assistant_state.rb       # conversation history + tool result cache
      client.rb                # abstract HTTP client base
      tool.rb                  # optional base class for tools
      tool_serializer.rb       # converts tool classes to JSON Schema hashes
      usage.rb                 # value object for token consumption data
      errors.rb                # RequestFail, ToolSerializationError, UndefinedTool
      open_ai/
        roles.rb
        client.rb
        assistant.rb
      gemini/
        roles.rb
        client.rb
        assistant.rb
      anthropic/
        roles.rb
        client.rb
        assistant.rb
      mcp/
        server.rb              # Rack middleware exposing tools via JSON-RPC 2.0
        tools_registry.rb      # per-request tool registry used by the middleware
        client.rb              # HTTP client for MCP servers
        errors.rb

spec/
  minitest_helper.rb           # test config, shared tool class (GoalsByPlayer)
  support/helpers/
    erb.rb                     # ERB rendering helper for JSON resource templates
    resources.rb               # read_resource / read_json_resource helpers
  resources/
    open_ai/                   # ERB-templated JSON fixtures
    gemini/
    anthropic/
  open_ai/
    client_spec.rb
    assistant_spec.rb
  gemini/
    client_spec.rb
    assistant_spec.rb
  anthropic/
    client_spec.rb
    assistant_spec.rb
  mcp/
    client_spec.rb
    server_spec.rb
    tools_registry_spec.rb
  tool_serializer_spec.rb
```


## Key runtime dependencies

| Gem | Role |
|---|---|
| `multi_require` | Auto-requires all files matching a glob pattern (alphabetically sorted) |
| `rasti-form` | Typed structs used as tool parameter schemas |
| `rasti-model` | Typed value objects (e.g. `Usage`) |
| `class_config` | DSL for `attr_config` on modules — provides the `Rasti::AI.configure` block |
| `inflecto` | String inflection: `underscore` and `demodulize` to derive tool names from class names |
| `net/http` | HTTP client (stdlib, no extra gem) |


## Provider API differences

| | OpenAI | Gemini | Anthropic |
|---|---|---|---|
| Auth | `Authorization: Bearer {key}` | `?key=` query param | `x-api-key: {key}` + `anthropic-version: 2023-06-01` header |
| Endpoint | `POST /chat/completions` | `POST /models/{model}:generateContent` | `POST /messages` |
| System prompt | message with `role: system` | top-level `system_instruction` | top-level `system` string |
| `max_tokens` | optional | optional | **required** (default 4096 in client) |
| Tool schema key | `parameters` | `parameters` | `input_schema` |
| Tool choice | `"tool_choice": "auto"` | _(not sent)_ | `"tool_choice": {"type": "auto"}` |
| Tool result role | `tool` | `function` | `user` (with content block `type: tool_result`) |
| Tool args in response | JSON string in `function.arguments` | object in `functionCall.args` | object in `input` |
| Stop signal | `choices[0].finish_reason` | `candidates[0].finishReason` | `stop_reason` |
| `json_schema` impl | native `response_format` | native `generation_config.response_schema` | forced tool use: adds `structured_output` tool + `tool_choice: {type: tool}` |

`ToolSerializer` always outputs `inputSchema`. Each provider renames it in `wrap_tool_serialization`:
- OpenAI: keeps as-is (passes `inputSchema` directly, API accepts it)
- Gemini: renames to `parameters`
- Anthropic: renames to `input_schema`


## Thinking levels

The base `Assistant` accepts `thinking: 'low' | 'medium' | 'high'` (validated on construction; nil = disabled). Each provider translates it in a private `thinking_config` method and passes the result to the client. The client includes it in the request body only if present.

| Level | OpenAI `reasoning_effort` | Anthropic `budget_tokens` | Gemini `thinking_budget` |
|---|---|---|---|
| `'low'` | `'low'` | `1_024` | `1_024` |
| `'medium'` | `'medium'` | `8_000` | `8_192` |
| `'high'` | `'high'` | `16_000` | `24_576` |

For Gemini, `thinking_config` goes inside `generation_config` — the client doesn't need a new param. For OpenAI and Anthropic, it's a separate top-level param in the client method (`reasoning_effort:` and `thinking:` respectively).

The loop does not change. Anthropic thinking blocks (`type: 'thinking'`) in responses are ignored by `parse_content` (looks for `type == 'text'`) and preserved automatically by `build_assistant_tool_calls_message` (passes full `response['content']` array).


## Adding a new provider

Create three files under `lib/rasti/ai/<provider>/`:

1. **`roles.rb`** — string constants for role names
2. **`client.rb`** — inherits `Rasti::AI::Client`, implements the main API method + private helpers
3. **`assistant.rb`** — inherits `Rasti::AI::Assistant`, implements all 12 template methods

Add to `lib/rasti/ai.rb`:
```ruby
attr_config :<provider>_api_key,       ENV['<PROVIDER>_API_KEY']
attr_config :<provider>_default_model, ENV['<PROVIDER>_DEFAULT_MODEL']
```

If the new provider supports thinking, define a `THINKING_LEVELS` constant and a private `thinking_config` method (see existing providers). The base constructor already validates and exposes `thinking`.

Add an entry to the `PROVIDERS` table in `tasks/assistant.rake` so the interactive task is also available for the new provider:

```ruby
PROVIDERS = {
  # existing providers ...
  '<provider>' => {key: '<PROVIDER>_API_KEY', klass: -> { Rasti::AI::<Provider>::Assistant }}
}.freeze
```

The task name, description, env-key check, logger path and banner are all derived automatically from this entry.

Add to `spec/minitest_helper.rb`:
```ruby
config.<provider>_api_key       = 'test_<provider>_api_key'
config.<provider>_default_model = '<provider>-test'
```

### ⚠️ multi_require load order

`require_relative_pattern 'ai/**/*'` loads files alphabetically. If the new provider name sorts before `assistant` or `client` (e.g. `anthropic` < `assistant`), the subclass is loaded before the base class and raises `NameError`.

**Fix already in place**: `lib/rasti/ai.rb` explicitly requires the base classes before the pattern:

```ruby
require_relative 'ai/errors'
require_relative 'ai/usage'
require_relative 'ai/assistant_state'
require_relative 'ai/tool'
require_relative 'ai/tool_serializer'
require_relative 'ai/client'
require_relative 'ai/assistant'
require_relative_pattern 'ai/**/*'   # duplicates are skipped by Ruby's require
```

If you add a provider whose name sorts before `client` alphabetically, the same mechanism protects it.


## Code conventions

### Constants

Constants are always defined at the **top of the class body, before `private`**. Never inside the `private` section or between method definitions.

```ruby
class Client < Rasti::AI::Client

  ANTHROPIC_VERSION  = '2023-06-01'.freeze
  DEFAULT_MAX_TOKENS = 4096

  private

  def base_url ...
end
```

This also applies to per-provider constants in `Assistant` subclasses (`THINKING_LEVELS`, `ALLOWED_SCHEMA_FIELDS`, etc.).

### Frozen strings

All string constants use `.freeze`. Integer and array/hash literals that are already frozen by `%w[]`/`.freeze` on the outer value don't need it again on the inner elements. Integers never need `.freeze`.

```ruby
USER = 'user'.freeze
ASSISTANT = 'assistant'.freeze

VALID_THINKING_LEVELS = %w[low medium high].freeze

THINKING_LEVELS = {
  'low' => {thinking_budget: 1_024}.freeze,
  'medium' => {thinking_budget: 8_192}.freeze,
}.freeze
```

### Building request bodies

Start with the required keys, then conditionally add optional ones. Never include optional fields as `nil`.

```ruby
body = {
  model: model || Rasti::AI.anthropic_default_model,
  max_tokens: max_tokens || DEFAULT_MAX_TOKENS,
  messages: messages
}

body[:thinking] = thinking if thinking
body[:system] = system if system
body[:tools] = tools unless tools.empty?
body[:tool_choice] = tool_choice if tool_choice
```

### Hash alignment

Use `key: value` without padding spaces. Do not align values across keys:

```ruby
{
  model: model,
  max_tokens: DEFAULT_MAX_TOKENS,
  messages: messages
}
```

Nested hashes always go on their own lines, indented one level. Never inline a multi-key hash next to its parent key or inside an array bracket:

```ruby
# Preferred
{
  role: Roles::USER,
  content: [
    {
      type: 'tool_result',
      tool_use_id: tool_call['id'],
      content: result
    }
  ]
}

# Avoid
{
  role:    Roles::USER,
  content: [{
    type:        'tool_result',
    tool_use_id: tool_call['id'],
    content:     result
  }]
}
```

Exception: a single-key nested hash that fits naturally on one line can stay inline (e.g. `THINKING_LEVELS` entries). Apply judgment — the goal is always readability.

### Parentheses

Omit parentheses in method calls when they add no clarity — particularly in single-argument calls, `if`/`unless` conditions, and DSL-style invocations:

```ruby
# Preferred
raise NotImplementedError
attr_reader :client
puts response

# Avoid
raise(NotImplementedError)
attr_reader(:client)
puts(response)
```

Include parentheses when the call uses splat, double-splat, or block arguments (`*`, `**`, `&`), or when omitting them causes ambiguity in a complex expression:

```ruby
# Required — splat/block args
object.forward(*args, &block)

# Required — disambiguate argument boundary in compound conditions
if tool && tool.class.respond_to?(:form)  # correct
if tool && tool.class.respond_to? :form   # wrong: :form is parsed as arg to &&

# Required — call is the value of a hash key or inside an array literal with a constant arg
# (Ruby 2.3 parser raises SyntaxError: unexpected tCONSTANT)
{ inputSchema: ToolSerializer.serialize_form(SumTool::Form) }   # correct
{ inputSchema: ToolSerializer.serialize_form SumTool::Form }    # wrong: SyntaxError in Ruby 2.3
[ToolSerializer.serialize(HelloWorldTool)]                      # correct
[ToolSerializer.serialize HelloWorldTool]                       # wrong: SyntaxError in Ruby 2.3

# Required — call is an intermediate argument in a multi-arg call
# (without parens the outer parser greedily passes subsequent args to the inner call)
post path, JSON.dump(body), 'CONTENT_TYPE' => 'application/json'   # correct
post path, JSON.dump body, 'CONTENT_TYPE' => 'application/json'    # wrong: 'CONTENT_TYPE' => ... is passed to JSON.dump

# Fine without parentheses — multiple regular args
http.post '/path', body: '{}'
calc.sum 1, 2
```

### `private` and `attr_reader`

`private` is placed immediately after the class-level constants (if any) and before all method definitions. `attr_reader` always lives inside the `private` section — never in the public interface unless the attribute is intentionally public (e.g. `state`, `model`, `thinking` on `Assistant`).

```ruby
class Assistant < Rasti::AI::Assistant

  THINKING_LEVELS = { ... }.freeze

  private

  attr_reader :client, :json_schema, :tools, :serialized_tools, :logger

  def build_default_client ...
end
```

### Instance variables (`@`)

Avoid bare `@variable` references in method bodies. Always declare an `attr_reader` inside the `private` section, then access the attribute by its reader name throughout the class. Direct `@` usage is only acceptable inside `initialize` assignments and inside the writer itself.

```ruby
# Bad — @session_id scattered across methods
def request_with_session(method, params={})
  raise unless e.message =~ /session/i && @session_id.nil?
end

# Good — declared once, accessed via reader everywhere
private

attr_reader :session_id

def request_with_session(method, params={})
  raise unless e.message =~ /session/i && session_id.nil?
end

def initialize_session
  @session_id = response['mcp-session-id']  # @ only for assignment
end
```

### Keyword arguments

All method signatures use keyword arguments. Required params have no default; optional params default to `nil`, `[]`, `{}`, or `false` as appropriate.

```ruby
def messages(messages:, model:nil, system:nil, tools:[], tool_choice:nil, thinking:nil)
```

### Template methods

Abstract methods in base classes always raise `NotImplementedError` with no message. Do not use `raise NotImplementedError, "override me"` — the bare form is the convention.

```ruby
def build_default_client
  raise NotImplementedError
end
```

### No unused constants

Don't leave constants defined unless they are referenced in the same file. If a constant was added in anticipation of future use, remove it until it's actually needed.

### Ruby compatibility

The gem must run on Ruby **2.3 and later**. Do not use language features or stdlib methods introduced after 2.3. Common pitfalls:

| Avoid | Use instead |
|---|---|
| `hash.transform_keys { \|k\| ... }` | `Hash[hash.map { \|k, v\| [transform(k), v] }]` |
| `hash.filter { ... }` | `hash.select { ... }` |
| Numbered block params (`_1`, `_2`) | Named block params (`\|k, v\|`) |
| Pattern matching (`case/in`) | `case/when` or conditionals |
| `Array#sum` with initial value | `inject(:+)` or `reduce` |
| `Hash#slice` | `select` + key check |

When in doubt, check the Ruby 2.3 docs or test against the lowest version in the CI matrix.


## Test conventions

### Framework and libraries

- **Minitest** with `describe`/`it` blocks (spec style)
- **WebMock** for HTTP stubbing — real connections are disabled in all tests
- **Minitest::Mock** for mock objects

### JSON fixtures with ERB

Request/response bodies live in `spec/resources/<provider>/` as ERB-templated JSON files. Use `read_resource` to render them:

```ruby
read_resource('anthropic/basic_request.json', model: model, prompt: question)
# => '{"model":"claude-test","max_tokens":4096,...}'

read_json_resource('anthropic/basic_response.json', content: answer)
# => parsed Ruby hash
```

Template example (`basic_request.json`):
```
{"model":"<%= model %>","max_tokens":4096,"messages":[{"role":"user","content":"<%= prompt %>"}]}
```

Variables are set via `binding.local_variable_set` so any Ruby expression works inside `<%= %>`.

### Stubbing HTTP requests

```ruby
stub_request(:post, 'https://api.anthropic.com/v1/messages')
  .with(
    headers: {'x-api-key' => Rasti::AI.anthropic_api_key},
    body: read_resource('anthropic/basic_request.json', model: model, prompt: question)
  )
  .to_return(body: read_resource('anthropic/basic_response.json', content: answer))
```

Body matching is a string comparison, so JSON key order in the fixture must match exactly what the client sends (`JSON.dump` of a Ruby hash with symbol keys produces alphabetical-ish order based on insertion).

### Testing multi-turn tool flows

For tests involving tool calls (where the model calls a tool then continues), use `Minitest::Mock` on the client instead of HTTP stubs — it's simpler to set up multiple sequential responses:

```ruby
let(:client) { Minitest::Mock.new }

client.expect :messages, tool_response do |params|
  params[:messages].last[:role] == 'user' &&
    params[:messages].last[:content] == question
end

client.expect :messages, basic_response(answer) do |params|
  params[:messages].last[:content] == [{type: 'tool_result', ...}]
end

assistant = Rasti::AI::Anthropic::Assistant.new client: client, tools: [tool]
assistant.call question
client.verify
```

The block form of `expect` is used (instead of the positional args form) because keyword argument matching is more reliable with it across Ruby versions.

### Shared test tool

`GoalsByPlayer` is defined in `minitest_helper.rb` and used across all provider assistant specs:

```ruby
class GoalsByPlayer
  def self.form
    Rasti::Form[player: Rasti::Types::String, team: Rasti::Types::String]
  end

  def call(params={})
    '672'
  end
end
```

It's a simple class (not a `Tool` subclass) that returns a plain string — covering the most common tool interface.


## Development setup

- The minimum supported Ruby version is **2.3** (`required_ruby_version >= 2.3` in the gemspec). All code must run on 2.3 and every version up through the CI matrix ceiling. See [Ruby compatibility](#ruby-compatibility) in Code conventions.
- **Run tests**: `bundle exec rake spec`
- **Run a single file**: `bundle exec rake spec TEST=spec/anthropic/client_spec.rb`
- **Run a single test by line**: `bundle exec rake spec TEST=spec/anthropic/client_spec.rb:42`
- **Run by name**: `bundle exec rake spec NAME=tool`
- **Console**: `bundle exec rake console` (loads the gem + Pry)
- **Interactive chat** (requires provider API key in env):
  ```
  rake assistant:openai      # OPENAI_API_KEY
  rake assistant:gemini      # GEMINI_API_KEY
  rake assistant:anthropic   # ANTHROPIC_API_KEY
  ```
  Each task validates the key, writes logs to `log/<provider>.log`, connects to the [Pipeworx](https://pipeworx.io) public weather MCP server, and starts a `You:` / `Assistant:` prompt loop (`exit` or `Ctrl+C` to quit). The model can be overridden with the matching env variable (e.g. `OPENAI_DEFAULT_MODEL=gpt-4o`).


## CI

GitHub Actions — `.github/workflows/ci.yml`.

- **Matrix**: Ruby `2.3` through `3.3` + `jruby-9.4` (JRuby 9.4 = Ruby 3.1 compat)
- **`ruby/setup-ruby@v1`** with `bundler-cache: true` — handles `bundle install` and caching automatically, no separate install step needed
- **No native extensions** — do not add `libcurl4-openssl-dev` or `force_ruby_platform` steps; this gem uses only `net/http` (stdlib)
- **`required_ruby_version`** is set to `>= 2.3` in the gemspec, consistent with the matrix

> If adding Ruby versions beyond 3.3, verify that the dev dependencies (`rake ~> 12.0`, `minitest ~> 5.0, < 5.11`) still install. If they don't, the gemspec constraints will need updating.
