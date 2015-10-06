begin
  require 'rspec/core'
  require 'rspec/core/rake_task'
rescue LoadError
else
  desc "Run all specs in spec directory"
  RSpec::Core::RakeTask.new do |t|
    # from: vmdb's EvmTestHelper.init_rspec_task
    rspec_opts = ['--options', "\"#{File.join(GEMS_PENDING_ROOT, ".rspec_ci")}\""] + (rspec_opts || []) if ENV['CI']
    t.rspec_opts = rspec_opts
    t.verbose = false
    t.pattern = './spec{,/*/**}/*_spec.rb'
  end
end
