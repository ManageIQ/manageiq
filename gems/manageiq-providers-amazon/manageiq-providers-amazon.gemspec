$:.push File.expand_path("../lib", __FILE__)

require "manageiq/providers/amazon/version"

Gem::Specification.new do |s|
  s.name        = "manageiq-providers-amazon"
  s.version     = ManageIQ::Providers::Amazon::VERSION
  s.authors     = ["ManageIQ Developers"]
  s.homepage    = "https://github.com/ManageIQ/manageiq"
  s.summary     = "Amazon AWS Provider for ManageIQ"
  s.description = "Amazon AWS Provider for ManageIQ"
  s.licenses    = ["Apache-2.0"]

  s.files = Dir["{app,lib}/**/*"]

  s.add_dependency("aws-sdk", ["~>2.2.19"])
end
