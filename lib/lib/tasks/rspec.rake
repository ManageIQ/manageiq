require 'rspec/core'
require 'rspec/core/rake_task'

desc "Run all specs in spec directory"
RSpec::Core::RakeTask.new(:spec) do |t|
  rspec_opts_file = ".rspec#{"_ci" if ENV['CI']}"
  t.rspec_opts = ['--options', "\"#{File.join(LIB_ROOT, rspec_opts_file)}\""]
  t.verbose = false
end

namespace :spec do
  desc "Run all specs with rcov"
  RSpec::Core::RakeTask.new(:rcov) do |t|
    rspec_opts_file = ".rspec#{"_ci" if ENV['CI']}"
    t.rspec_opts = ['--options', "\"#{File.join(LIB_ROOT, rspec_opts_file)}\""]
    t.verbose = false

    t.rcov = true
    t.rcov_opts = lambda do
      rcov_opts_file = File.expand_path(File.join(File.dirname(__FILE__), "spec", "rcov.opts"))
      IO.readlines(rcov_opts_file).map {|l| l.chomp.split " "}.flatten
    end
  end
end
