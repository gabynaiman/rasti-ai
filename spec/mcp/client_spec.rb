require 'minitest_helper'

describe Rasti::AI::MCP::Client do

  let(:mcp_url) { 'https://mcp.server.ai/mcp' }

  let(:client) { Rasti::AI::MCP::Client.new(url: mcp_url) }

  let(:client_with_allowed_tools) { Rasti::AI::MCP::Client.new(url: mcp_url, allowed_tools: ['sum_tool']) }

  def stub_mcp_request(method, params:{}, result:{}, error:nil)
    request_body = {
      jsonrpc: '2.0',
      method: method,
      params: params
    }

    response_body = {
      jsonrpc: '2.0'
    }

    if error
      response_body[:error] = error
    else
      response_body[:result] = result
    end

    stub_request(:post, mcp_url)
      .with(
        body: JSON.dump(request_body),
        headers: {'Content-Type' => 'application/json'}
      )
      .to_return(
        body: JSON.dump(response_body),
        headers: {'Content-Type' => 'application/json'}
      )
  end

  describe 'List tools' do

    it 'Returns all tools when no allowed_tools' do
      tools = [
        {
          'name' => 'hello_world_tool',
          'description' => 'Hello World'
        },
        {
          'name' => 'sum_tool',
          'description' => 'Sum two numbers'
        }
      ]

      stub_mcp_request 'tools/list', result: {'tools' => tools}

      result = client.list_tools

      assert_equal tools, result
    end

    it 'Returns empty list when no tools available' do
      stub_mcp_request 'tools/list', result: {'tools' => []}

      result = client.list_tools

      assert_equal [], result
    end

    it 'Filters tools by allowed_tools' do
      tools = [
        {
          'name' => 'hello_world_tool',
          'description' => 'Hello World'
        },
        {
          'name' => 'sum_tool',
          'description' => 'Sum two numbers'
        },
        {
          'name' => 'multiply_tool',
          'description' => 'Multiply'
        }
      ]

      stub_mcp_request 'tools/list', result: {'tools' => tools}

      result = client_with_allowed_tools.list_tools

      expected = [
        {
          'name' => 'sum_tool',
          'description' => 'Sum two numbers'
        }
      ]

      assert_equal expected, result
    end

    it 'Returns empty when no tools match allowed_tools' do
      tools = [
        {
          'name' => 'hello_world_tool',
          'description' => 'Hello World'
        },
        {
          'name' => 'multiply_tool',
          'description' => 'Multiply'
        }
      ]

      stub_mcp_request 'tools/list', result: {'tools' => tools}

      result = client_with_allowed_tools.list_tools

      assert_equal [], result
    end

  end

  describe 'Call tool' do

    it 'Executes tool with arguments' do
      params = {
        name: 'sum_tool',
        arguments: {
          number_a: 1,
          number_b: 2
        }
      }

      result_content = {
        'content' => [
          {
            'type' => 'text',
            'text' => '{"result":3.0}'
          }
        ]
      }

      stub_mcp_request 'tools/call', params: params, result: result_content

      result = client.call_tool 'sum_tool', number_a: 1, number_b: 2

      assert_equal '{"type":"text","text":"{\"result\":3.0}"}', result
    end

    it 'Executes tool without arguments' do
      params = {
        name: 'hello_world_tool',
        arguments: {}
      }

      result_content = {
        'content' => [
          {
            'type' => 'text',
            'text' => '{"text":"Hello world"}'
          }
        ]
      }

      stub_mcp_request 'tools/call', params: params, result: result_content

      result = client.call_tool 'hello_world_tool'

      assert_equal '{"type":"text","text":"{\"text\":\"Hello world\"}"}', result
    end

    it 'Raises error when tool not in allowed_tools' do
      error = assert_raises RuntimeError do
        client_with_allowed_tools.call_tool 'hello_world_tool'
      end

      assert_equal 'Invalid tool: hello_world_tool', error.message
    end

    it 'Allows tool call when in allowed_tools' do
      params = {
        name: 'sum_tool',
        arguments: {
          number_a: 5,
          number_b: 3
        }
      }

      result_content = {
        'content' => [
          {
            'type' => 'text',
            'text' => '{"result":8.0}'
          }
        ]
      }

      stub_mcp_request 'tools/call', params: params, result: result_content

      result = client_with_allowed_tools.call_tool 'sum_tool', number_a: 5, number_b: 3

      assert_equal '{"type":"text","text":"{\"result\":8.0}"}', result
    end

  end

  describe 'Error handling' do

    it 'Raises error when MCP returns error' do
      error_response = {
        'code' => -32603,
        'message' => 'Tool not found'
      }

      params = {
        name: 'nonexistent',
        arguments: {}
      }

      stub_mcp_request 'tools/call', params: params, error: error_response

      error = assert_raises RuntimeError do
        client.call_tool 'nonexistent'
      end

      assert_equal 'MCP Error: Tool not found', error.message
    end

    it 'Raises error when result is missing' do
      stub_request(:post, mcp_url)
        .to_return(
          status: 200,
          body: JSON.dump({ jsonrpc: '2.0' }),
          headers: { 'Content-Type' => 'application/json' }
        )

      error = assert_raises RuntimeError do
        client.list_tools
      end

      assert_equal 'MCP Error: invalid result', error.message
    end

    it 'Raises error when response is invalid JSON' do
      stub_request(:post, mcp_url)
        .to_return(
          status: 200,
          body: 'invalid json{',
          headers: {'Content-Type' => 'application/json'}
        )

      error = assert_raises JSON::ParserError do
        client.list_tools
      end

      assert_match /unexpected token/, error.message
    end

  end
end