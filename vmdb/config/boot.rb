require 'rubygems'

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require File.expand_path('../../../lib/bundler_setup', __FILE__)

CFME::BundlerSetup.system_setup(ENV['BUNDLE_GEMFILE'], :default) if File.exists?(ENV['BUNDLE_GEMFILE'])
