module EvmTestHelper
  def self.init_rspec_task(t, rspec_opts = [])
    if ENV['CI']
      rspec_ci = defined?(ENGINE_ROOT) ? File.join(ENGINE_ROOT, ".rspec_ci") : Rails.root.join(".rspec_ci")
      rspec_opts.unshift('--options', rspec_ci)
    end
    t.rspec_opts = rspec_opts
    t.verbose = false
  end

  def self.vmdb_spec_directories
    # TODO: Clean up this thing
    #
    # This is required because parallel_tests takes directories
    # RSpec will sort out the parsing of _spec.rb's within them, too!
    #
    # Output: %w(./spec/controllers ./spec/helpers ./spec/initializers ..)
    Dir.glob("./spec/*").select do |d|
      File.directory?(d) && !Dir.glob("#{d}/**/*_spec.rb").empty?
    end
  end
end
