module EvmTestHelper
  VMDB_SPECS        = FileList["spec/**/*_spec.rb"].exclude(/^spec\/(replication|migrations|automation)/)
  REPLICATION_SPECS      = FileList['spec/replication/replication_spec.rb']
  REPLICATION_UTIL_SPECS = FileList['spec/replication/util/*_spec.rb']
  MIGRATION_SPECS        = FileList['spec/migrations/**/*_spec.rb'].sort
  AUTOMATION_SPECS       = FileList['spec/automation/**/*_spec.rb']

  def self.init_rspec_task(t, rspec_opts = [])
    rspec_opts = ['--options', "\"#{Rails.root.join(".rspec_ci")}\""] + rspec_opts if ENV['CI']
    t.rspec_opts = rspec_opts
    t.verbose = false
  end

  def self.run_rake_via_shell(rake_command, env = {})
    cmd = "bundle exec rake #{rake_command}"
    cmd << " --trace" if Rake.application.options.trace
    _pid, status = Process.wait2(Kernel.spawn(env, cmd, :chdir => Rails.root))
    exit(status.exitstatus) if status.exitstatus != 0
  end
end
