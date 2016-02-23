$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "provider_amazon/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "provider_amazon"
  s.version     = ProviderAmazon::VERSION
  s.authors     = ["Marcel Hild"]
  s.email       = ["hild@b4mad.net"]
  s.homepage    = ""
  s.summary     = "Summary of ProviderAmazon."
  s.description = "Description of ProviderAmazon."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 5.0.0.beta2", "< 5.1"

  s.add_development_dependency "sqlite3"
end
