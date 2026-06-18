require 'minitest_helper'

describe Rasti::AI::MCP::Server do

  class ErrorTool < Rasti::AI::Tool
    def execute(form)
      raise 'Unexpected tool error'
    end
  end

  include Rack::Test::Methods

  let(:app) do
    inner = lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['App response']] }
    Rasti::AI::MCP::Server.new inner
  end

  before do
    Rasti::AI::MCP::Server.restore_default_configuration
  end

  def post_mcp_request(method, params={})
    request_data = {
      jsonrpc: '2.0',
      id: 1,
      method: method
    }
    request_data[:params] = params unless params.empty?

    post Rasti::AI::MCP::Server.relative_path, JSON.dump(request_data), 'CONTENT_TYPE' => 'application/json'
  end

  def assert_jsonrpc_success(expected_result)
    expected_response = {
      jsonrpc: '2.0',
      id: 1,
      result: expected_result
    }

    assert_equal 200, last_response.status
    assert_equal 'application/json', last_response.content_type
    assert_equal_json JSON.dump(expected_response), last_response.body
  end

  def assert_jsonrpc_error(expected_error)
    expected_response = {
      jsonrpc: '2.0',
      id: 1,
      error: expected_error
    }

    assert_equal 200, last_response.status
    assert_equal 'application/json', last_response.content_type
    assert_equal_json JSON.dump(expected_response), last_response.body
  end

  describe 'Initialize request' do

    it 'Returns protocol version and capabilities' do
      post_mcp_request 'initialize'

      expected_result = {
        protocolVersion: '2024-11-05',
        capabilities: {
          tools: {
            list: true,
            call: true
          }
        },
        serverInfo: {
          name: 'MCP Server',
          version: '1.0.0'
        }
      }

      assert_jsonrpc_success expected_result
    end

    it 'Custom server configuration' do
      Rasti::AI::MCP::Server.configure do |config|
        config.server_name    = 'Custom MCP Server'
        config.server_version = '2.0.0'
      end

      post_mcp_request 'initialize'

      expected_result = {
        protocolVersion: '2024-11-05',
        capabilities: {
          tools: {
            list: true,
            call: true
          }
        },
        serverInfo: {
          name: 'Custom MCP Server',
          version: '2.0.0'
        }
      }

      assert_jsonrpc_success expected_result
    end

  end

  describe 'Tools list request' do

    it 'Returns empty list when no builder configured' do
      post_mcp_request 'tools/list'

      assert_jsonrpc_success tools: []
    end

    it 'Returns tools registered in builder' do
      Rasti::AI::MCP::Server.configure do |config|
        config.load_tools do |tools_registry, _request|
          tools_registry.register tool: HelloWorldTool.new
          tools_registry.register tool: SumTool.new
        end
      end

      post_mcp_request 'tools/list'

      expected_result = {
        tools: [
          Rasti::AI::ToolSerializer.serialize(HelloWorldTool),
          Rasti::AI::ToolSerializer.serialize(SumTool)
        ]
      }

      assert_jsonrpc_success expected_result
    end

    it 'Passes request to builder' do
      received_path = nil

      Rasti::AI::MCP::Server.configure do |config|
        config.load_tools do |tools_registry, request|
          received_path = request.path
        end
      end

      post_mcp_request 'tools/list'

      assert_equal '/mcp', received_path
    end

    it 'Builder runs on every request' do
      call_count = 0

      Rasti::AI::MCP::Server.configure do |config|
        config.load_tools do |tools_registry, _request|
          call_count += 1
        end
      end

      post_mcp_request 'tools/list'
      post_mcp_request 'tools/list'

      assert_equal 2, call_count
    end

  end

  describe 'Tools call request' do

    before do
      Rasti::AI::MCP::Server.configure do |config|
        config.load_tools do |tools_registry, _request|
          tools_registry.register tool: HelloWorldTool.new
          tools_registry.register tool: SumTool.new
        end
      end
    end

    it 'Executes tool with arguments' do
      params = {
        name: 'sum_tool',
        arguments: {
          number_a: 1,
          number_b: 2
        }
      }

      post_mcp_request 'tools/call', params

      expected_result = {
        content: [
          {
            type: 'text',
            text: '{"result":3.0}'
          }
        ]
      }

      assert_jsonrpc_success expected_result
    end

    it 'Executes tool without arguments' do
      post_mcp_request 'tools/call', name: 'hello_world_tool'

      expected_result = {
        content: [
          {
            type: 'text',
            text: '{"text":"Hello world"}'
          }
        ]
      }

      assert_jsonrpc_success expected_result
    end

    it 'Executes block-registered tool' do
      Rasti::AI::MCP::Server.configure do |config|
        config.load_tools do |tools_registry, _request|
          schema = {type: 'object', properties: {text: {type: 'string'}}}
          tools_registry.register name: 'echo', description: 'Echo text', input_schema: schema do |args|
            args['text']
          end
        end
      end

      post_mcp_request 'tools/call', name: 'echo', arguments: {text: 'hello'}

      expected_result = {
        content: [
          {
            type: 'text',
            text: 'hello'
          }
        ]
      }

      assert_jsonrpc_success expected_result
    end

    it 'Receives request context in builder during tool call' do
      received_header = nil

      Rasti::AI::MCP::Server.configure do |config|
        config.load_tools do |tools_registry, request|
          received_header = request.env['HTTP_X_USER_ID']
          tools_registry.register tool: HelloWorldTool.new
        end
      end

      header 'X-User-Id', '42'
      post_mcp_request 'tools/call', name: 'hello_world_tool'

      assert_equal '42', received_header
    end

    it 'Tool call with nonexistent tool returns error' do
      post_mcp_request 'tools/call', name: 'nonexistent'

      expected_error = {
        code: -32603,
        message: 'Tool nonexistent not found'
      }

      assert_jsonrpc_error expected_error
    end

    it 'Tool execution error returns error response' do
      Rasti::AI::MCP::Server.configure do |config|
        config.load_tools do |tools_registry, _request|
          tools_registry.register tool: ErrorTool.new
        end
      end

      post_mcp_request 'tools/call', name: 'error_tool'

      expected_error = {
        code: -32603,
        message: 'Unexpected tool error'
      }

      assert_jsonrpc_error expected_error
    end

  end

  describe 'Error handling' do

    it 'Method not found' do
      post_mcp_request 'invalid/method'

      expected_error = {
        code: -32601,
        message: 'Method not found'
      }

      assert_jsonrpc_error expected_error
    end

    it 'Invalid JSON returns parse error' do
      post Rasti::AI::MCP::Server.relative_path, 'not valid json', 'CONTENT_TYPE' => 'application/json'

      assert_equal 400, last_response.status
    end

  end

  describe 'Authentication' do

    def assert_unauthorized
      expected_response = {
        jsonrpc: '2.0',
        id: nil,
        error: {
          code: -32002,
          message: 'Unauthorized'
        }
      }

      assert_equal 401, last_response.status
      assert_equal 'application/json', last_response.content_type
      assert_equal_json JSON.dump(expected_response), last_response.body
    end

    it 'Allows request when no authenticator configured' do
      post_mcp_request 'initialize'

      assert_equal 200, last_response.status
    end

    it 'Allows request when authenticator returns true' do
      Rasti::AI::MCP::Server.configure do |config|
        config.authenticate { |_request| true }
      end

      post_mcp_request 'initialize'

      assert_equal 200, last_response.status
    end

    it 'Rejects initialize when authenticator returns false' do
      Rasti::AI::MCP::Server.configure do |config|
        config.authenticate { |_request| false }
      end

      post_mcp_request 'initialize'

      assert_unauthorized
    end

    it 'Rejects tools/list when authenticator returns false' do
      Rasti::AI::MCP::Server.configure do |config|
        config.authenticate { |_request| false }
      end

      post_mcp_request 'tools/list'

      assert_unauthorized
    end

    it 'Rejects tools/call when authenticator returns false' do
      Rasti::AI::MCP::Server.configure do |config|
        config.authenticate { |_request| false }
      end

      post_mcp_request 'tools/call', name: 'any_tool'

      assert_unauthorized
    end

    it 'Validates bearer token from Authorization header' do
      Rasti::AI::MCP::Server.configure do |config|
        config.authenticate { |request| request.env['HTTP_AUTHORIZATION'] == 'Bearer secret' }
        config.load_tools { |registry, _| registry.register tool: HelloWorldTool.new }
      end

      post_mcp_request 'tools/list'
      assert_unauthorized

      header 'Authorization', 'Bearer secret'
      post_mcp_request 'tools/list'
      assert_equal 200, last_response.status
    end

    it 'Does not call load_tools when authentication fails' do
      tools_loader_called = false

      Rasti::AI::MCP::Server.configure do |config|
        config.authenticate { |_request| false }
        config.load_tools do |registry, _|
          tools_loader_called = true
          registry.register tool: HelloWorldTool.new
        end
      end

      post_mcp_request 'tools/list'

      assert_equal false, tools_loader_called
    end

  end

  describe 'Request routing' do

    it 'GET requests to MCP path passed to app' do
      get '/mcp'

      assert_equal 200, last_response.status
      assert_equal 'App response', last_response.body
    end

    it 'POST to different path passed to app' do
      post '/other/path'

      assert_equal 200, last_response.status
      assert_equal 'App response', last_response.body
    end

    it 'Custom relative path' do
      Rasti::AI::MCP::Server.configure do |config|
        config.relative_path = '/path/too/custom_mcp'
      end

      post '/mcp'
      assert_equal 200, last_response.status
      assert_equal 'App response', last_response.body

      post_mcp_request 'tools/list'
      assert_jsonrpc_success tools: []
    end

  end

end
