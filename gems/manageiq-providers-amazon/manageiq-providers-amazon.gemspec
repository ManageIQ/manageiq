$:.push File.expand_path("../lib", __FILE__)

require "manageiq/providers/amazon/version"

Gem::Specification.new do |s|
  s.name        = "manageiq-providers-amazon"
  s.version     = ManageIQ::Providers::Amazon::VERSION
  s.authors     = ["https://github.com/ManageIQ/manageiq/blob/master/AUTHORS"]
  s.homepage    = "https://github.com/ManageIQ/manageiq"
  s.summary     = "Amazon AWS Provider for ManageIQ"
  s.description = "Amazon AWS Provider for ManageIQ"
  s.licenses    = ["GPL-2.0", "Apache-2.0"]

  s.files = Dir["{app,lib}/**/*"]
end
