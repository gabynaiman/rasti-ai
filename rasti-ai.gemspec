# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rasti/ai/version'

Gem::Specification.new do |spec|
  spec.name          = 'rasti-ai'
  spec.version       = Rasti::AI::VERSION
  spec.authors       = ['Gabriel Naiman']
  spec.email         = ['gabynaiman@gmail.com']
  spec.summary       = 'AI for apps'
  spec.description   = 'AI for apps'
  spec.homepage      = 'https://github.com/gabynaiman/rasti-ai'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'multi_require', '~> 1.0'
  spec.add_runtime_dependency 'rasti-form', '~> 6.0'
  spec.add_runtime_dependency 'inflecto', '~> 0.0'
  spec.add_runtime_dependency 'class_config', '~> 0.0'
  spec.add_runtime_dependency 'http', '~> 4.0'

  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'minitest', '~> 5.0', '< 5.11'
  spec.add_development_dependency 'minitest-colorin', '~> 0.1'
  spec.add_development_dependency 'minitest-line', '~> 0.6'
  spec.add_development_dependency 'simplecov', '~> 0.12'
  spec.add_development_dependency 'coveralls', '~> 0.8'
  spec.add_development_dependency 'pry-nav', '~> 0.2'
  spec.add_development_dependency 'webmock', '~> 3.0'
end