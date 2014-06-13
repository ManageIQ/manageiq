
desc "Run all lib tests except MiqDisk tests"
task :test do
  ARGV.clear # HACK: rake/runtest inspects ARGV, which is different when run
             #       from the miq directory
  require 'rake/runtest'
  (Dir.glob("./test/ts_*.rb") - ["./test/ts_mdfs.rb"]).each do |test|
    Rake.run_tests(test)
  end
end

namespace :test do
  desc "Run lib MiqDisk tests"
  task :miq_disk do
    ARGV.clear # HACK: rake/runtest inspects ARGV, which is different when run
               #       from the miq directory
    require 'rake/runtest'
    Rake.run_tests("./test/ts_mdfs.rb")
  end
end