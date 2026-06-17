# frozen_string_literal: true

require 'fileutils'
require 'logger'

# Interactive CLI to chat with an AI assistant backed by a public weather MCP server.
#
# The Pipeworx weather MCP is free, requires no auth key, and exposes:
#   get_weather    — current conditions for any city or lat/lon
#   get_forecast   — daily forecast up to 16 days ahead
#   get_historical — historical weather back to 1940
# Docs: https://pipeworx.io
#
# Usage:
#   rake assistant:openai      # requires OPENAI_API_KEY    (+ optionally OPENAI_DEFAULT_MODEL)
#   rake assistant:gemini      # requires GEMINI_API_KEY    (+ optionally GEMINI_DEFAULT_MODEL)
#   rake assistant:anthropic   # requires ANTHROPIC_API_KEY (+ optionally ANTHROPIC_DEFAULT_MODEL)

WEATHER_MCP_URL = 'https://gateway.pipeworx.io/weather/mcp'.freeze

PROVIDERS = {
  'openai'    => {key: 'OPENAI_API_KEY',    klass: -> { Rasti::AI::OpenAI::Assistant }},
  'gemini'    => {key: 'GEMINI_API_KEY',    klass: -> { Rasti::AI::Gemini::Assistant }},
  'anthropic' => {key: 'ANTHROPIC_API_KEY', klass: -> { Rasti::AI::Anthropic::Assistant }}
}.freeze

def build_weather_mcp
  Rasti::AI::MCP::Client.new(
    url: WEATHER_MCP_URL,
    allowed_tools: ['get_weather', 'get_forecast', 'get_historical']
  )
end

def print_banner(provider, tool_names)
  puts
  puts '=' * 60
  puts "  Rasti AI Chat — #{provider}"
  puts "  MCP: #{WEATHER_MCP_URL}"
  puts "  Tools: #{tool_names.join(', ')}"
  puts '=' * 60
  puts "  Type your message and press Enter."
  puts "  Type 'exit' or press Ctrl+C to quit."
  puts '=' * 60
  puts
end

def chat_loop(assistant)
  loop do
    print 'You: '
    $stdout.flush

    input = $stdin.gets&.chomp
    break if input.nil? || input.strip.downcase == 'exit'
    next  if input.strip.empty?

    begin
      response = assistant.call(input.strip)
      puts
      puts "Assistant: #{response}"
      puts
    rescue Interrupt
      break
    rescue => e
      puts "\n[Error] #{e.message}\n"
    end
  end

  puts "\nGoodbye!"
end

def start_assistant(provider, env_key, assistant_klass)
  require 'rasti-ai'

  abort "[Error] #{env_key} is not set." unless ENV[env_key]

  FileUtils.mkdir_p 'log'
  Rasti::AI.configure { |c| c.logger = Logger.new("log/#{provider}.log") }

  mcp = build_weather_mcp
  print_banner provider.capitalize, mcp.list_tools.map { |t| t['name'] }

  chat_loop assistant_klass.call.new(mcp_servers: {weather: mcp})
end

namespace :assistant do

  PROVIDERS.each do |provider, config|
    desc "Chat with #{provider.capitalize} assistant using Pipeworx weather MCP (requires #{config[:key]})"
    task provider.to_sym do
      start_assistant(provider, config[:key], config[:klass])
    end
  end

end
