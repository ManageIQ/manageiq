#
# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
end
