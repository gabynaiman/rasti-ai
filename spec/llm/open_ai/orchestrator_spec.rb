require 'minitest_helper'

describe Rasti::AI::LLM::OpenAI::Orchestrator do

  let(:api_url) { 'https://api.openai.com/v1/chat/completions' }

  let(:question) { 'How many goals has Messi scored for Barca?' }

  let(:answer) { 'Lionel Messi scored 672 goals in 778 official matches for FC Barcelona.' }

  let(:instructions) { 'Act as sports journalist' }

  def system_message(content)
    Rasti::AI::Message.from_system(content: content).to_h
  end
  
  def user_message(content)
    Rasti::AI::Message.from_user(content: content).to_h
  end
  
  def assistant_message(content)
    Rasti::AI::Message.from_assistant(content: content).to_h
  end

  def basic_request(user_content)
   JSON.dump({
      model: Rasti::AI.openai_default_model,
      messages: [
        system_message(instructions),
        user_message(user_content)
      ],
      tools: [],
      tool_choice: 'none'
    })
  end

  def basic_response(assistant_content)
    JSON.dump({
      id: 'chatcmpl-123',
      object: 'chat.completion',
      created: 1677652288,
      model: 'gpt-4',
      choices: [
        {
          index: 0,
          message: {
            role: 'assistant',
            content: assistant_content
          },
          finish_reason: 'stop'
        }
      ]
    })
  end

  def tool_call_response(tool_call_id:, tool_name:, arguments:)
    {
      id: 'chatcmpl-123',
      object: 'chat.completion',
      created: 1677652288,
      model: 'gpt-4',
      choices: [{
        index: 0,
        message: {
          role: 'assistant',
          tool_calls: [{
            id: tool_call_id,
            type: 'function',
            function: {
              name: tool_name,
              arguments: JSON.dump(arguments)
            }
          }]
        },
        finish_reason: 'tool_calls'
      }]
    }
  end

  def build_session
    llm = Rasti::AI::LLM::Configuration.new provider: 'OPEN_AI'
    configuration = Rasti::AI::Agent::Configuration.new llm: llm, instructions: instructions
    Rasti::AI::Agent::Session.new configuration: configuration
  end

  describe 'Basic conversation' do

    it 'Simple question and answer' do
      stub_request(:post, api_url)
        .with(body: basic_request(question))
        .to_return(body: basic_response(answer))
      
      session = build_session
      orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

      response = orchestrator.call question

      expected_messages = [
        Rasti::AI::Message.from_system(content: instructions),
        Rasti::AI::Message.from_user(content: question),
        Rasti::AI::Message.from_assistant(content: answer)
      ]
      
      assert_equal answer, response
      assert_equal expected_messages, session.all_messages
    end

    # it 'Maintains conversation history' do
    #   session = build_session

    #   previous_question = 'Who is Messi?'
    #   previous_answer = 'Lionel Messi is an Argentine footballer.'

    #   first_request = {
    #     model: Rasti::AI.openai_default_model,
    #     messages: [user_message(previous_question)],
    #     tools: []
    #   }

    #   stub_request(:post, api_url)
    #     .with(body: JSON.dump(first_request))
    #     .to_return(body: JSON.dump(basic_response(previous_answer)))

    #   second_request = {
    #     model: Rasti::AI.openai_default_model,
    #     messages: [
    #       user_message(previous_question),
    #       assistant_message(previous_answer),
    #       user_message(question)
    #     ],
    #     tools: []
    #   }

    #   stub_request(:post, api_url)
    #     .with(body: JSON.dump(second_request))
    #     .to_return(body: JSON.dump(basic_response(answer)))

    #   orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

    #   orchestrator.call previous_question
    #   response = orchestrator.call question

    #   assert_equal answer, response
    #   assert_equal 4, session.messages.count
    # end

    # it 'Uses custom model from configuration' do
    #   custom_model = 'gpt-4-turbo'
      
    #   configuration = Rasti::AI::Agent::Configuration.new do |config|
    #     config.llm.model = custom_model
    #   end

    #   session = Rasti::AI::Agent::Session.new configuration: configuration

    #   request_body = {
    #     model: custom_model,
    #     messages: [user_message(question)],
    #     tools: []
    #   }

    #   stub_request(:post, api_url)
    #     .with(body: JSON.dump(request_body))
    #     .to_return(body: JSON.dump(basic_response(answer)))

    #   orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

    #   response = orchestrator.call question

    #   assert_equal answer, response
    # end

    # it 'Uses custom logger' do
    #   log_output = StringIO.new
    #   logger = Logger.new log_output

    #   session = build_session

    #   request_body = {
    #     model: Rasti::AI.openai_default_model,
    #     messages: [user_message(question)],
    #     tools: []
    #   }

    #   stub_request(:post, api_url)
    #     .with(body: JSON.dump(request_body))
    #     .to_return(body: JSON.dump(basic_response(answer)))

    #   orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session, logger: logger

    #   response = orchestrator.call question

    #   assert_equal answer, response
    #   refute_empty log_output.string
    # end

    # it 'Uses context from session' do
    #   context = 'Act as sports journalist'
    #   session = build_session context: context

    #   request_body = {
    #     model: Rasti::AI.openai_default_model,
    #     messages: [
    #       {role: Rasti::AI::Roles.system, content: context},
    #       user_message(question)
    #     ],
    #     tools: []
    #   }

    #   stub_request(:post, api_url)
    #     .with(body: JSON.dump(request_body))
    #     .to_return(body: JSON.dump(basic_response(answer)))

    #   orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

    #   response = orchestrator.call question

    #   assert_equal answer, response
    # end

  end

  # describe 'Tools' do

  #   class GoalsByPlayer < Rasti::AI::Tool
  #     def self.form
  #       Rasti::Form[player: Rasti::Types::String, team: Rasti::Types::String]
  #     end

  #     def call(params={})
  #       '672'
  #     end
  #   end

  #   let(:tool) { GoalsByPlayer.new }

  #   let(:tool_serialization) do
  #     {
  #       type: 'function',
  #       function: {
  #         name: 'goals_by_player',
  #         inputSchema: {
  #           type: 'object',
  #           properties: {
  #             player: {type: 'string'},
  #             team: {type: 'string'}
  #           }
  #         }
  #       }
  #     }
  #   end

  #   let(:tool_call_id) { 'call_abc123' }

  #   let(:tool_arguments) do
  #     {
  #       player: 'Lionel Messi',
  #       team: 'Barcelona'
  #     }
  #   end

  #   let(:tool_result) { '672' }

  #   it 'Calls tool and returns final answer' do
  #     session = build_session tools: [tool]

  #     first_request = {
  #       model: Rasti::AI.openai_default_model,
  #       messages: [user_message(question)],
  #       tools: [tool_serialization]
  #     }

  #     stub_request(:post, api_url)
  #       .with(body: JSON.dump(first_request))
  #       .to_return(body: JSON.dump(tool_call_response(
  #         tool_call_id: tool_call_id,
  #         tool_name: 'goals_by_player',
  #         arguments: tool_arguments
  #       )))

  #     second_request = {
  #       model: Rasti::AI.openai_default_model,
  #       messages: [
  #         user_message(question),
  #         {
  #           role: Rasti::AI::Roles.assistant,
  #           tool_calls: [{
  #             id: tool_call_id,
  #             type: 'function',
  #             function: {
  #               name: 'goals_by_player',
  #               arguments: JSON.dump(tool_arguments)
  #             }
  #           }]
  #         },
  #         {
  #           role: Rasti::AI::Roles.tool,
  #           tool_call_id: tool_call_id,
  #           content: tool_result
  #         }
  #       ],
  #       tools: [tool_serialization]
  #     }

  #     stub_request(:post, api_url)
  #       .with(body: JSON.dump(second_request))
  #       .to_return(body: JSON.dump(basic_response(answer)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     response = orchestrator.call question

  #     assert_equal answer, response
  #     assert_equal 4, session.messages.count
  #   end

  #   it 'Handles tool execution error' do
  #     error_tool = tool.dup
  #     error_tool.define_singleton_method :call do |*args|
  #       raise 'Broken tool'
  #     end

  #     session = build_session tools: [error_tool]

  #     error_message = 'There was an error using the tool'

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(tools: [tool_serialization]))
  #       .to_return(body: JSON.dump(tool_call_response(
  #         tool_call_id: tool_call_id,
  #         tool_name: 'goals_by_player',
  #         arguments: tool_arguments
  #       )))

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(
  #         messages: array_including(
  #           hash_including(
  #             role: Rasti::AI::Roles.tool,
  #             content: 'Error: Broken tool'
  #           )
  #         )
  #       ))
  #       .to_return(body: JSON.dump(basic_response(error_message)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     response = orchestrator.call question

  #     assert_equal error_message, response
  #   end

  #   it 'Handles undefined tool error' do
  #     session = build_session tools: []

  #     error_message = 'The requested tool does not exist'

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(tools: []))
  #       .to_return(body: JSON.dump(tool_call_response(
  #         tool_call_id: tool_call_id,
  #         tool_name: 'goals_by_player',
  #         arguments: tool_arguments
  #       )))

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(
  #         messages: array_including(
  #           hash_including(
  #             role: Rasti::AI::Roles.tool,
  #             content: 'Error: Undefined tool goals_by_player'
  #           )
  #         )
  #       ))
  #       .to_return(body: JSON.dump(basic_response(error_message)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     response = orchestrator.call question

  #     assert_equal error_message, response
  #   end

  #   it 'Handles multiple sequential tool calls' do
  #     tool_call_id_2 = 'call_def456'
  #     tool_arguments_2 = {
  #       player: 'Cristiano Ronaldo',
  #       team: 'Real Madrid'
  #     }

  #     session = build_session tools: [tool]

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(tools: [tool_serialization]))
  #       .to_return(body: JSON.dump(tool_call_response(
  #         tool_call_id: tool_call_id,
  #         tool_name: 'goals_by_player',
  #         arguments: tool_arguments
  #       )))
  #       .then
  #       .to_return(body: JSON.dump(tool_call_response(
  #         tool_call_id: tool_call_id_2,
  #         tool_name: 'goals_by_player',
  #         arguments: tool_arguments_2
  #       )))
  #       .then
  #       .to_return(body: JSON.dump(basic_response(answer)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     response = orchestrator.call question

  #     assert_equal answer, response
  #     assert_equal 6, session.messages.count
  #   end

  #   it 'Logs tool execution' do
  #     log_output = StringIO.new
  #     logger = Logger.new log_output

  #     session = build_session tools: [tool]

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(tools: [tool_serialization]))
  #       .to_return(body: JSON.dump(tool_call_response(
  #         tool_call_id: tool_call_id,
  #         tool_name: 'goals_by_player',
  #         arguments: tool_arguments
  #       )))

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(
  #         messages: array_including(
  #           hash_including(role: Rasti::AI::Roles.tool)
  #         )
  #       ))
  #       .to_return(body: JSON.dump(basic_response(answer)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session, logger: logger

  #     response = orchestrator.call question

  #     assert_equal answer, response
  #     assert_includes log_output.string, 'Calling function goals_by_player'
  #     assert_includes log_output.string, 'Function result: 672'
  #   end

  #   it 'Logs tool error' do
  #     log_output = StringIO.new
  #     logger = Logger.new log_output

  #     error_tool = tool.dup
  #     error_tool.define_singleton_method :call do |*args|
  #       raise 'Broken tool'
  #     end

  #     session = build_session tools: [error_tool]

  #     error_message = 'There was an error'

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(tools: [tool_serialization]))
  #       .to_return(body: JSON.dump(tool_call_response(
  #         tool_call_id: tool_call_id,
  #         tool_name: 'goals_by_player',
  #         arguments: tool_arguments
  #       )))

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(
  #         messages: array_including(
  #           hash_including(
  #             role: Rasti::AI::Roles.tool,
  #             content: 'Error: Broken tool'
  #           )
  #         )
  #       ))
  #       .to_return(body: JSON.dump(basic_response(error_message)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session, logger: logger

  #     response = orchestrator.call question

  #     assert_equal error_message, response
  #     assert_includes log_output.string, 'Function failed: Broken tool'
  #   end

  # end

  # describe 'MCP Servers' do

  #   let(:mcp_url) { 'http://localhost:3000/mcp' }

  #   let(:tool_call_id) { 'call_mcp123' }

  #   def mcp_list_tools_response(tools)
  #     {
  #       jsonrpc: '2.0',
  #       id: 1,
  #       result: {
  #         tools: tools
  #       }
  #     }
  #   end

  #   def mcp_call_tool_response(result)
  #     {
  #       jsonrpc: '2.0',
  #       id: 2,
  #       result: {
  #         content: [
  #           {type: 'text', text: result}
  #         ]
  #       }
  #     }
  #   end

  #   def stub_mcp_list_tools(url:, tools:)
  #     list_request = {
  #       jsonrpc: '2.0',
  #       id: 1,
  #       method: 'tools/list'
  #     }

  #     stub_request(:post, url)
  #       .with(body: JSON.dump(list_request))
  #       .to_return(body: JSON.dump(mcp_list_tools_response(tools)))
  #   end

  #   def stub_mcp_call_tool(url:, tool_name:, arguments:, result:)
  #     call_request = {
  #       jsonrpc: '2.0',
  #       id: 2,
  #       method: 'tools/call',
  #       params: {
  #         name: tool_name,
  #         arguments: arguments
  #       }
  #     }

  #     stub_request(:post, url)
  #       .with(body: JSON.dump(call_request))
  #       .to_return(body: JSON.dump(mcp_call_tool_response(result)))
  #   end

  #   it 'Lists and calls MCP tools' do
  #     mcp_tools = [
  #       {
  #         'name' => 'search',
  #         'description' => 'Search for information',
  #         'inputSchema' => {
  #           'type' => 'object',
  #           'properties' => {
  #             'query' => {'type' => 'string'}
  #           }
  #         }
  #       }
  #     ]

  #     mcp_config = Rasti::AI::MCP::Configuration.new url: mcp_url
  #     mcp_servers = {'web' => mcp_config}
  #     session = build_session mcp_servers: mcp_servers

  #     stub_mcp_list_tools url: mcp_url, tools: mcp_tools

  #     wrapped_tool = {
  #       type: 'function',
  #       function: {
  #         name: 'web_search',
  #         description: 'Search for information',
  #         inputSchema: {
  #           type: 'object',
  #           properties: {
  #             query: {type: 'string'}
  #           }
  #         }
  #       }
  #     }

  #     search_arguments = {query: 'messi goals barcelona'}

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(tools: [wrapped_tool]))
  #       .to_return(body: JSON.dump(tool_call_response(
  #         tool_call_id: tool_call_id,
  #         tool_name: 'web_search',
  #         arguments: search_arguments
  #       )))

  #     stub_mcp_call_tool url: mcp_url,
  #                       tool_name: 'search',
  #                       arguments: search_arguments,
  #                       result: 'Search results'

  #     stub_request(:post, api_url)
  #       .with(body: hash_including(
  #         messages: array_including(
  #           hash_including(role: Rasti::AI::Roles.tool, content: 'Search results')
  #         )
  #       ))
  #       .to_return(body: JSON.dump(basic_response(answer)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     response = orchestrator.call question

  #     assert_equal answer, response
  #   end

  #   it 'MCP tool with prefix in name' do
  #     mcp_tools = [
  #       {
  #         'name' => 'search',
  #         'description' => 'Search for information',
  #         'inputSchema' => {
  #           'type' => 'object',
  #           'properties' => {
  #             'query' => {'type' => 'string'}
  #           }
  #         }
  #       }
  #     ]

  #     mcp_config = Rasti::AI::MCPConfig.new url: mcp_url
  #     mcp_servers = {'web' => mcp_config}
  #     session = build_session mcp_servers: mcp_servers

  #     stub_mcp_list_tools url: mcp_url, tools: mcp_tools

  #     stub_request(:post, api_url)
  #       .to_return(body: JSON.dump(basic_response(answer)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     # Trigger tool initialization
  #     orchestrator.call question

  #     # Verify tool name has prefix
  #     tools = orchestrator.send(:tools)
  #     assert tools.key?('web_search')
  #     refute tools.key?('search')
  #   end

  #   it 'Combines regular tools and MCP tools' do
  #     class SampleTool < Rasti::AI::Tool
  #       def call(params={})
  #         'sample result'
  #       end
  #     end

  #     regular_tool = SampleTool.new

  #     mcp_tools = [
  #       {
  #         'name' => 'search',
  #         'description' => 'Search',
  #         'inputSchema' => {
  #           'type' => 'object',
  #           'properties' => {
  #             'query' => {'type' => 'string'}
  #           }
  #         }
  #       }
  #     ]

  #     mcp_config = Rasti::AI::MCPConfig.new url: mcp_url
  #     mcp_servers = {'web' => mcp_config}
  #     session = build_session tools: [regular_tool], mcp_servers: mcp_servers

  #     stub_mcp_list_tools url: mcp_url, tools: mcp_tools

  #     stub_request(:post, api_url)
  #       .to_return(body: JSON.dump(basic_response(answer)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     orchestrator.call question

  #     tools = orchestrator.send(:tools)
  #     assert tools.key?('sample_tool')
  #     assert tools.key?('web_search')
  #   end

  # end

  # describe 'Output Schema' do

  #   it 'Sends response format when output schema configured' do
  #     output_schema = {
  #       name: 'player_goals',
  #       schema: {
  #         type: 'object',
  #         properties: {
  #           goals: {type: 'integer'}
  #         }
  #       }
  #     }

  #     session = build_session output_schema: output_schema

  #     response_format = {
  #       type: 'json_schema',
  #       json_schema: output_schema
  #     }

  #     request_body = {
  #       model: Rasti::AI.openai_default_model,
  #       messages: [user_message(question)],
  #       tools: [],
  #       response_format: response_format
  #     }

  #     json_answer = '{"goals": 672}'

  #     stub_request(:post, api_url)
  #       .with(body: JSON.dump(request_body))
  #       .to_return(body: JSON.dump(basic_response(json_answer)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     response = orchestrator.call question

  #     assert_equal json_answer, response
  #   end

  #   it 'No response format when output schema is nil' do
  #     session = build_session output_schema: nil

  #     request_body = {
  #       model: Rasti::AI.openai_default_model,
  #       messages: [user_message(question)],
  #       tools: []
  #     }

  #     stub_request(:post, api_url)
  #       .with(body: JSON.dump(request_body))
  #       .to_return(body: JSON.dump(basic_response(answer)))

  #     orchestrator = Rasti::AI::LLM::OpenAI::Orchestrator.new session: session

  #     response = orchestrator.call question

  #     assert_equal answer, response
  #   end

  # end

end