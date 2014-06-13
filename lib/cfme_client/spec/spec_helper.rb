
#
# Push the lib directory onto the load path
#
$LOAD_PATH.push(File.expand_path(File.join(File.dirname(__FILE__), '..')))

#
# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#
Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support', '**', '*.rb'))].each { |f| require f }

RSpec.configure do |config|
  config.color_enabled = true
  config.tty = true
  config.formatter = :documentation
end
