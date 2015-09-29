namespace :test do
  namespace :self_service do
    desc "Setup environment for self_service tests"
    task :setup # NOOP - Stub for consistent CI testing
  end

  desc "Run all self_service tests"
  task :self_service => :initialize do
    _pid, status = Process.wait2(
      spawn("npm test", :chdir => File.join(__dir__, "../../spa_ui/self_service"))
    )
    exit status.exitstatus if status.exitstatus != 0
  end
end
