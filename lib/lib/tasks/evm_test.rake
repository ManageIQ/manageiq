
desc "Run all lib tests except MiqDisk tests"
task :test do
  require 'rake/runtest'
  (Dir.glob("./test/ts_*.rb") - ["./test/ts_mdfs.rb"]).each do |test|
    Rake.run_tests(test)
  end
end

namespace :test do
  desc "Run lib MiqDisk tests"
  task :miq_disk do
    require 'rake/runtest'
    Rake.run_tests("./test/ts_mdfs.rb")
  end
end
