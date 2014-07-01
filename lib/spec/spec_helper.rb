require_relative '../bundler_setup'
require 'rspec/autorun'

# Push the lib directory onto the load path
LIB_ROOT ||= File.expand_path(File.dirname(__FILE__)+"../..")
$:.push(LIB_ROOT)

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
  # won't run coverage if gem not loaded
end

RSpec.configure do |config|
end
