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
end
