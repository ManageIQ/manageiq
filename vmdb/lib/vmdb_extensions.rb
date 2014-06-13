$:.push("#{File.dirname(__FILE__)}/extensions")
Dir.glob(File.expand_path(File.join(File.dirname(__FILE__), "extensions", "*.rb"))) { |f| require File.basename(f, ".*") }
