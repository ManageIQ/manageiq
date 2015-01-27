begin
  require 'rspec/core'
  require 'rspec/core/rake_task'
rescue LoadError
else
  desc "Run all specs in spec directory"
  RSpec::Core::RakeTask.new do |t|
    # from: vmdb's EvmTestHelper.init_rspec_task
    rspec_opts = ['--options', "\"#{File.join(LIB_ROOT, ".rspec_ci")}\""] + (rspec_opts || []) if ENV['CI']
    t.rspec_opts = rspec_opts
    t.verbose = false
    t.pattern = './spec{,/*/**}/*_spec.rb'
  end

  namespace :spec do
    desc "Run all specs in manageiq_foreman directory"
    RSpec::Core::RakeTask.new('foreman') do |t|
      # from: vmdb's EvmTestHelper.init_rspec_task
      rspec_opts = ['--options', "\"#{File.join(LIB_ROOT, ".rspec_ci")}\""] + (rspec_opts || []) if ENV['CI']
      t.rspec_opts = rspec_opts
      t.verbose = false
      t.pattern = './manageiq_foreman/spec/*_spec.rb'
    end
  end
end
