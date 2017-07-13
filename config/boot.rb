if ENV["WITH_BUNDLER_CACHE"]
  $LOAD_PATH.clear
  $LOAD_PATH.insert(0, *File.read(".bundler.loadpath_cache").lines.map(&:strip))

  require 'bundler/rubygems_integration'
  Bundler.rubygems.reverse_rubygems_kernel_mixin
else
  require 'rubygems'

  # Set up gems listed in the Gemfile.
  ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

  require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])

  # add the lib dir of the engine if we are running as a dummy app for an engine
  $LOAD_PATH.unshift File.expand_path('../../../lib', __dir__) if defined?(ENGINE_ROOT)
end
