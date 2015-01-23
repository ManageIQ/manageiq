# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manageiq_foreman/version'

Gem::Specification.new do |spec|
  spec.name          = "manageiq_foreman"
  spec.version       = ManageiqForeman::VERSION
  spec.authors       = ["Keenan Brock"]
  spec.email         = ["keenan@thebrocks.net"]
  spec.description   = %q{Foreman Provider for ManageIQ}
  spec.summary       = %q{Foreman Provider for ManageIQ}
  spec.homepage      = "http://github.com/manageiq/manageiq_foreman"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "foreman_api"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "rspec"

  spec.add_development_dependency "pry"
end
