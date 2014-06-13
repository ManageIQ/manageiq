$:.push("#{File.dirname(__FILE__)}/ar_adapter")
Dir.glob(File.expand_path(File.join(File.dirname(__FILE__), "ar_adapter", "*.rb"))) { |f| require File.basename(f, ".*") }
