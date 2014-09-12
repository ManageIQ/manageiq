ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

# If run through cruisecontrol, write the normal $log messages to the cruise
# control build artifacts logger
if ENV['CC_BUILD_ARTIFACTS']
  $log.filename = File.expand_path(File.join(ENV['CC_BUILD_ARTIFACTS'], "evm.log"))
  cc_level = VMDBLogger::INFO
end

# Set env var LOG_TO_CONSOLE if you want logging to dump to the console
# e.g. LOG_TO_CONSOLE=true ruby spec/models/vm.rb
$log.logdev = STDERR if ENV['LOG_TO_CONSOLE']

# Set env var LOGLEVEL if you want custom log level during a local test
# e.g. LOG_LEVEL=debug ruby spec/models/vm.rb
env_level = VMDBLogger.const_get(ENV['LOG_LEVEL'].to_s.upcase) rescue nil if ENV['LOG_LEVEL']

$log.level = env_level || cc_level || VMDBLogger::INFO
Rails.logger.level = $log.level

class ActiveSupport::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # The only drawback to using transactional fixtures is when you actually
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  #fixtures :all

  # Add more helper methods to be used by all tests here...

  teardown :clear_caches

  # Clear all EVM caches at the end of every test before tearing down the DB changes
  def clear_caches
    Module.clear_all_cache_with_timeout if Module.respond_to?(:clear_all_cache_with_timeout)

    # Clear any cached MiqEnvironment variables
    ivars = MiqEnvironment::Command.instance_variables
    ivars.each { |i| MiqEnvironment::Command.instance_variable_set(i.to_sym, nil) }
  end

  # See DatabaseAdapterTest
  def assert_leakproof(iterations)
    $log.info("tracking objects with #{iterations} iterations...")
    # Yield once to establish a baseline set of objects
    yield

    GC.start
    GC.disable
    existing_objects = Hash.new(0)
    leaks = []
    ObjectSpace.each_object {|obj| existing_objects[obj.class] -= 1 }

    iterations.to_i.times { yield }

  ensure
    GC.enable
    GC.start
    ObjectSpace.each_object {|obj| existing_objects[obj.class] += 1 }

    existing_objects.each do |name, count|
      leaks << "  class: #{name}: count: #{count}" if count > 0
    end

    assert_equal 0, leaks.length, "Expected no leaks, found: \n#{leaks.join("\n")}"
  end

end

def toggle_on_name_seq(x)
  x.name.split("_").last.to_i % 2 != 0
end
