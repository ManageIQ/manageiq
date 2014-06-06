require 'rspec/core'
require 'rspec/core/rake_task'
if default = Rake.application.instance_variable_get('@tasks')['default']
  default.prerequisites.delete('test')
end

spec_prereq = :noop
task :noop do; end
task :default => :spec

desc "Run all specs in spec directory"
RSpec::Core::RakeTask.new(:spec => spec_prereq) do |t|
  rspec_opts_file = ".rspec#{"_cc" if ENV['CC_BUILD_ARTIFACTS']}"
  t.rspec_opts = ['--options', "\"#{File.expand_path(File.join(File.dirname(__FILE__), rspec_opts_file))}\""]
end

namespace :spec do
  desc "Run all specs with rcov"
  RSpec::Core::RakeTask.new(:rcov => spec_prereq) do |t|
    rspec_opts_file = ".rspec#{"_cc" if ENV['CC_BUILD_ARTIFACTS']}"
    t.rspec_opts = ['--options', "\"#{File.expand_path(File.join(File.dirname(__FILE__), rspec_opts_file))}\""]
    t.rcov = true
    t.rcov_opts = lambda do
      rcov_opts_file = File.expand_path(File.join(File.dirname(__FILE__), "spec", "rcov.opts"))
      IO.readlines(rcov_opts_file).map {|l| l.chomp.split " "}.flatten
    end
  end
end
