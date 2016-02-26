$:.push File.expand_path("../app", __FILE__)

# Maintain your gem's version:
require "models/manageiq/providers/amazon/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "manageiq-providers-amazon"
  s.version     = ManageIQ::Providers::Amazon::VERSION
  s.authors     = ["Marcel Hild"]
  s.email       = ["hild@b4mad.net"]
  s.homepage    = "https://github.com/ManageIQ/manageiq"
  s.summary     = "AWS Provider for ManageIQ"
  s.description = "AWS Provider for ManageIQ"
  s.license     = "MIT"

  s.files = Dir["{app,lib}/**/*"]
end
