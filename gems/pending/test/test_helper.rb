require_relative "../bundler_setup"

if ENV["TRAVIS"]
  require 'coveralls'
  Coveralls.wear_merged! { add_filter("/test/") }
end

require 'minitest/autorun'

# Push the lib directory onto the load path
$:.push(File.expand_path(File.join(File.dirname(__FILE__), '..')))
