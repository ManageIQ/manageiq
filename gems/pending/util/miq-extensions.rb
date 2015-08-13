require_relative "../bundler_setup"
require 'more_core_extensions/all'

Dir.glob(File.expand_path(File.join(File.dirname(__FILE__), "extensions", "*.rb"))) { |f| require_relative "extensions/#{File.basename(f, ".*")}" }
