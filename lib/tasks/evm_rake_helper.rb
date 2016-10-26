module EvmRakeHelper
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
end
