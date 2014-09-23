module EvmTestHelper
  BACKEND_SPECS     = FileList["spec/**/*_spec.rb"].exclude(/^spec\/(replication|gems|migrations|automation|requests)/)
  METRICS_SPECS     = BACKEND_SPECS + ['spec/coverage_helper.rb']
  REPLICATION_SPECS = FileList['spec/replication/**/*_spec.rb']
  MIGRATION_SPECS   = FileList['spec/migrations/**/*_spec.rb'].sort
  AUTOMATION_SPECS  = FileList['spec/automation/**/*_spec.rb']

  def self.run_rake_via_shell(rake_command, env = {})
    cmd = "bundle exec rake #{rake_command}"
    cmd << " --trace" if Rake.application.options.trace
    _pid, status = Process.wait2(Kernel.spawn(env, cmd, :chdir => Rails.root))
    exit(status.exitstatus) if status.exitstatus != 0
  end
end
