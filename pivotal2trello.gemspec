# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pivotal2trello/version'

Gem::Specification.new do |spec|
  spec.name          = "pivotal2trello"
  spec.version       = Pivotal2Trello::VERSION
  spec.authors       = ["Eric Steil III"]
  spec.email         = ["eric@localist.com"]
  spec.summary       = %q{Migrate tasks from Pivotal Tracker to Trello}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency 'activesupport', '~> 4.2'
  spec.add_dependency 'tracker_api', '~> 0.2'
  spec.add_dependency 'ruby-trello', '~> 1.3'
  spec.add_dependency 'multi_json'
  spec.add_dependency 'commander', '~> 4.3'
end
