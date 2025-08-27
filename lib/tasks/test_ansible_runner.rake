namespace :test do
  desc "Run ansible_runner execution tests"
  task :ansible_runner_execution do
    exec File.expand_path("../../bin/test_ansible_runner_execution", __dir__)
  end
end
