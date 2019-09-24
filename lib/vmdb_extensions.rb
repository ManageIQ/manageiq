Dir.glob(File.expand_path(File.join(__dir__, "extensions", "*.rb"))).sort.each { |f| require f }
