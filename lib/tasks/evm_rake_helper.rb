module EvmRakeHelper

  EVM_APPLIANCE_TASKS = %w[
    evm:start
    evm:restart
    evm:stop
    evm:kill
    evm:status
    evm:status_full
  ]

  # Loading environment will try to read database.yml unless DATABASE_URL is set.
  # For some rake tasks, the database.yml may not yet be setup and is not required anyway.
  # Note: Rails will not actually use the configuration and connect until you issue a query.
  def self.with_dummy_database_url_configuration
    before, ENV["DATABASE_URL"] = ENV["DATABASE_URL"], "postgresql:///not_existing_db?host=/var/lib/postgresql"
    yield
  ensure
    # ENV['x'] = nil deletes the key because ENV accepts only string values
    ENV["DATABASE_URL"] = before
  end

  # Returns any command ARGV options.
  #
  # If ARGV contains the 'end of options' '--' option [1]:
  # Returns a duplicate of ARGV with all arguments up to and including
  # the '--' removed.
  #   [1] http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html
  #
  # Otherwise, returns a duplicate of ARGV, since there is no obvious subcommand.
  #
  # Example 1:
  #   bundle exec evm:db:region -- --region 1
  #
  # ARGV starts as:
  #   ["evm:db:region", "--", "--region", "1"]
  # Returns:
  #   ["--region", "1"]
  #
  # Example 2:
  #   bundle exec evm:db:region --region 1
  # ARGV starts as =>
  #   ["evm:db:region", "--region", "1"]
  # Returns:
  #   ["evm:db:region", "--region", "1"]
  def self.extract_command_options
    i = ARGV.index("--")
    i ? ARGV.slice((i + 1)..-1) : ARGV.dup
  end

  # Loads the necessary rake task files given the ARGUMENTS passed to rake
  #
  # Tasks like like evm:status should be snappy, and don't really require a lot
  # of depdendencies to function.  But by loading config/application.rb and
  # using the Vmdb::Application.load_tasks interface, we boot up and configure
  # the entire application to load every task that we need, when that is
  # usually overkill.
  #
  # By doing a small of ARGV analysis, we can quickly determine what files are
  # actually needed for the tasks being requested, and skip loading a large
  # portion of the code base.
  def self.load_rake_environment
    if only_calling_evm_tasks
      load_evm_rake_tasks
    else
      load_all_rake_tasks
    end
  end

  # Loads everything normally via the Rails conventions
  def self.load_all_rake_tasks
    require File.expand_path("../../../config/application", __FILE__)

    Vmdb::Application.load_tasks

    # Clear noisy and unusable tasks added by rspec-rails
    if defined?(RSpec)
      Rake::Task.tasks.select { |t| t.name =~ /^spec(:)?/ }.each(&:clear)
    end
  end

  # Loads only the evm.rake, and sets up the path for that
  def self.load_evm_rake_tasks
    $:.push(File.expand_path("../../", __FILE__))

    load File.expand_path("../evm.rake", __FILE__)
  end

  # Determines if we are only using evm application tasks
  def self.only_calling_evm_tasks
    ARGV.all? {|arg| EVM_APPLIANCE_TASKS.include?(arg)}
  end
end
