require_relative '../bundler_setup'
require 'rspec/autorun'

# Push the gems/pending directory onto the load path
GEMS_PENDING_ROOT ||= File.expand_path(File.join(__dir__, ".."))
$LOAD_PATH << GEMS_PENDING_ROOT

# Initialize the global logger that might be expected
require 'logger'
$log ||= Logger.new("/dev/null")

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(__dir__, 'support/**/*.rb'))].each { |f| require f }

begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
  # won't run coverage if gem not loaded
end

RSpec.configure do |config|
  config.after(:each) do
    Module.clear_all_cache_with_timeout if Module.respond_to?(:clear_all_cache_with_timeout)
  end

  config.backtrace_exclusion_patterns -= [%r{/lib\d*/ruby/}, %r{/gems/}]
  config.backtrace_exclusion_patterns << %r{/lib\d*/ruby/[0-9]}
  config.backtrace_exclusion_patterns << %r{/gems/[0-9][^/]+/gems/}
end
