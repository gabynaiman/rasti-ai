require 'minitest_helper'

describe Rasti::AI::MCP::Server do

  class HelloWorldTool < Rasti::AI::Tool
    def self.description
      'Hello World'
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

  class ErrorTool < Rasti::AI::Tool
    def execute(form)
      raise "Unexpected tool error"
    end
  end

  include Rack::Test::Methods

  let(:app) do
    app = lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['App response']] }
    Rasti::AI::MCP::Server.new app
  end

  before do
    Rasti::AI::MCP::Server.clear_tools
    Rasti::AI::MCP::Server.restore_default_configuration
  end

  def post_mcp_request(method, params={})
    request_data = {
      jsonrpc: '2.0',
      id: 1,
      method: method
    }
    request_data[:params] = params unless params.empty?

    post Rasti::AI::MCP::Server.relative_path, JSON.dump(request_data), CONTENT_TYPE: 'application/json'
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

  def assert_http_error(status, expected_error)
    expected_response = {
      jsonrpc: '2.0',
      id: nil,
      error: expected_error
    }
    
    assert_equal status, last_response.status
    assert_equal 'application/json', last_response.content_type
    assert_equal_json JSON.dump(expected_response), last_response.body
  end

  describe 'Tool registration' do

    it 'Register tool' do
      Rasti::AI::MCP::Server.register_tool HelloWorldTool.new
      Rasti::AI::MCP::Server.register_tool SumTool.new
      
      serializations = Rasti::AI::MCP::Server.tools_serializations

      expeted_serializations = [
        Rasti::AI::ToolSerializer.serialize(HelloWorldTool),
        Rasti::AI::ToolSerializer.serialize(SumTool)
      ]

      assert_equal expeted_serializations, serializations
    end

    it 'Register duplicate tool raises error' do
      Rasti::AI::MCP::Server.register_tool HelloWorldTool.new
      
      error = assert_raises RuntimeError do
        Rasti::AI::MCP::Server.register_tool HelloWorldTool.new
      end
      
      assert_equal 'Tool hello_world_tool already exist', error.message
    end

    it 'Tools serializations empty when no tools' do
      assert_empty Rasti::AI::MCP::Server.tools_serializations
    end

    it 'Call tool executes registered tool' do
      Rasti::AI::MCP::Server.register_tool HelloWorldTool.new
      
      result = Rasti::AI::MCP::Server.call_tool 'hello_world_tool'
      
      assert_equal '{"text":"Hello world"}', result
    end

    it 'Call tool not found raises error' do
      error = assert_raises RuntimeError do
        Rasti::AI::MCP::Server.call_tool 'non_existent', {}
      end
      
      assert_equal 'Tool non_existent not found', error.message
    end

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
        config.server_name = 'Custom MCP Server'
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

    it 'Returns empty list when no tools' do
      post_mcp_request 'tools/list'

      expected_result = {
        tools: []
      }

      assert_jsonrpc_success expected_result
    end

    it 'Returns registered tools' do
      Rasti::AI::MCP::Server.register_tool HelloWorldTool.new
      Rasti::AI::MCP::Server.register_tool SumTool.new

      post_mcp_request 'tools/list'

      expected_result = {
        tools: [
          Rasti::AI::ToolSerializer.serialize(HelloWorldTool),
          Rasti::AI::ToolSerializer.serialize(SumTool)
        ]
      }

      assert_jsonrpc_success expected_result
    end

  end

  describe 'Tools call request' do

    before do
      Rasti::AI::MCP::Server.register_tool HelloWorldTool.new
      Rasti::AI::MCP::Server.register_tool SumTool.new
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
      params = {
        name: 'hello_world_tool'
      }

      post_mcp_request 'tools/call', params

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

    it 'Tool call with nonexistent tool returns error' do
      params = {
        name: 'nonexistent'
      }

      post_mcp_request 'tools/call', params

      expected_error = {
        code: -32603,
        message: 'Tool nonexistent not found'
      }

      assert_jsonrpc_error expected_error
    end

    it 'Tool execution error returns error response' do
      Rasti::AI::MCP::Server.register_tool ErrorTool.new

      params = {
        name: 'error_tool'
      }

      post_mcp_request 'tools/call', params

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

    it 'Invalid JSON returns 400' do
      post '/mcp', 'invalid json{'

      expected_error = {
        code: -32700,
        message: "unexpected token at 'invalid json{'"
      }
      
      assert_http_error 400, expected_error 
    end

    it 'Unhandled exception returns 500' do
      app.stub :handle_initialize, ->(_) { raise 'Unexpected server error' } do
        post_mcp_request 'initialize'

        expected_error = {
          code: -32603,
          message: 'Unexpected server error'
        }
        
        assert_http_error 500, expected_error 
      end
    end

  end

  describe 'Middleware behavior' do

    it 'Non MCP requests passed to app' do
      get '/other/path'
      
      assert_equal 200, last_response.status
      assert_equal 'App response', last_response.body
    end

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