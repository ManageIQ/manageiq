require_relative '../bundler_setup'
require 'azure-armrest'
require 'vcr'

if ENV["TRAVIS"]
  require 'coveralls'
  Coveralls.wear_merged! { add_filter("/spec/") }
end

# Push the gems/pending directory onto the load path
GEMS_PENDING_ROOT ||= File.expand_path(File.join(__dir__, ".."))
$LOAD_PATH << GEMS_PENDING_ROOT

# Initialize the global logger that might be expected
require 'logger'
$log ||= Logger.new("/dev/null")
# $log ||= Logger.new(STDOUT)
# $log.level = Logger::DEBUG

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(__dir__, 'support/**/*.rb'))].each { |f| require f }

RSpec.configure do |config|
  config.after(:each) do
    Module.clear_all_cache_with_timeout if Module.respond_to?(:clear_all_cache_with_timeout)
  end

  if ENV["TRAVIS"]
    config.after(:suite) do
      require "spec/coverage_helper.rb"
    end
  end

  config.backtrace_exclusion_patterns -= [%r{/lib\d*/ruby/}, %r{/gems/}]
  config.backtrace_exclusion_patterns << %r{/lib\d*/ruby/[0-9]}
  config.backtrace_exclusion_patterns << %r{/gems/[0-9][^/]+/gems/}
end

#
# So tests can clear class-level caches between examples.
# TODO: Add this to the azure-armrest gem.
#
class Azure::Armrest::ArmrestService
  def self.clear_caches
    @@providers_hash = {}
    @@tokens         = {}
    @@subscriptions  = {}
  end
end

VCR.configure do |c|
  c.cassette_library_dir = TestEnvHelper.recordings_dir
  c.hook_into :webmock

  c.allow_http_connections_when_no_cassette = false
  c.default_cassette_options = {
    :record                         => :once,
    :allow_unused_http_interactions => true
  }

  TestEnvHelper.vcr_filter(c)

  # c.debug_logger = File.open(Rails.root.join("log", "vcr_debug.log"), "w")
end
