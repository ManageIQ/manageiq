require 'rspec/core'
require 'rspec/core/rake_task'

desc "Run all specs in spec directory"
RSpec::Core::RakeTask.new(:spec) do |t|
  rspec_opts_file = ".rspec#{"_ci" if ENV['CI']}"
  t.rspec_opts = ['--options', "\"#{File.join(LIB_ROOT, rspec_opts_file)}\""]
  t.verbose = false
end
