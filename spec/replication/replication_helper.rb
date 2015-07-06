require "spec_helper"

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/replication/support/ and its subdirectories.
Dir[Rails.root.join("spec/replication/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  # Removing transactions for replication tests, since testing involves
  #   shelling out to rake tasks, and thus the database must be persisted.
  config.use_transactional_fixtures = false
end
