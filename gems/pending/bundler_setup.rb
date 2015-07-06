ENV['BUNDLE_GEMFILE'] ||= File.expand_path("Gemfile", File.join(File.dirname(__FILE__)))

require 'rubygems'
require 'bundler/setup'
