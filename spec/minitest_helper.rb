require 'coverage_helper'
require 'minitest/autorun'
require 'minitest/colorin'
require 'minitest/extended_assertions'
require 'webmock/minitest'
require 'rack/test'
require 'pry-nav'
require 'rasti-ai'
require 'securerandom'

require_relative 'support/helpers/erb'
require_relative 'support/helpers/resources'


Rasti::AI.configure do |config|
  config.logger.level = Logger::FATAL

  config.http_max_retries = 1

  config.openai_api_key = 'test_api_key'
  config.openai_default_model = 'gpt-test'

  config.gemini_api_key = 'test_gemini_api_key'
  config.gemini_default_model = 'gemini-test'

  config.anthropic_api_key = 'test_anthropic_api_key'
  config.anthropic_default_model = 'claude-test'
end


class Minitest::Test

  include Support::Helpers::ERB
  include Support::Helpers::Resources

end

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

  def self.description
    'Sum two numbers'
  end

  def execute(form)
    {result: form.number_a + form.number_b}
  end
end


class GoalsByPlayer
  def self.form
    Rasti::Form[player: Rasti::Types::String, team: Rasti::Types::String]
  end

  def call(params={})
    '672'
  end
end