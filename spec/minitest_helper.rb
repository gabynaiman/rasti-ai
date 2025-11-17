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

  config.openai_api_key = 'test_api_key'
  config.openai_default_model = 'gpt-test'
end


class Minitest::Test

  include Support::Helpers::ERB
  include Support::Helpers::Resources

end