require "active_record/connection_adapters/postgresql_adapter"
Dir.glob(File.expand_path(File.join(__dir__, "ar_adapter", "*.rb"))).sort.each { |f| require f }
