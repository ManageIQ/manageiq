$:.push File.expand_path("../lib", __FILE__)

require "manageiq/providers/<%= provider_name %>/version"

Gem::Specification.new do |s|
  s.name        = "manageiq-providers-<%= provider_name %>"
  s.version     = ManageIQ::Providers::<%= class_name %>::VERSION
  s.authors     = ["ManageIQ Developers"]
  s.homepage    = "https://github.com/ManageIQ/manageiq-providers-<%= provider_name %>"
  s.summary     = "<%= class_name %> Provider for ManageIQ"
  s.description = "<%= class_name %> Provider for ManageIQ"
  s.licenses    = ["Apache-2.0"]

  s.files = Dir["{app,config.lib}/**/*"]

  s.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"
  s.add_development_dependency "simplecov"
end
