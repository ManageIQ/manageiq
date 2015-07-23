unless defined?(GEMS_PENDING_ROOT)
  GEMS_PENDING_ROOT = File.expand_path(__dir__)
  $LOAD_PATH << GEMS_PENDING_ROOT
end
ENV['BUNDLE_GEMFILE'] ||= File.join(GEMS_PENDING_ROOT, "Gemfile")

require 'rubygems'
require 'bundler/setup'
