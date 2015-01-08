module EvmTestHelper
  VMDB_SPECS        = FileList["spec/**/*_spec.rb"].exclude(/^spec\/(replication|gems|migrations|automation)/)
  METRICS_SPECS     = VMDB_SPECS + ['spec/coverage_helper.rb']
  REPLICATION_SPECS = FileList['spec/replication/**/*_spec.rb']
  MIGRATION_SPECS   = FileList['spec/migrations/**/*_spec.rb'].sort
  AUTOMATION_SPECS  = FileList['spec/automation/**/*_spec.rb']

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

  def self.cc_start_top
    return if $cc_top_parent_process_id
    if ENV['CC_BUILD_ARTIFACTS'] && File.exist?(ENV['CC_BUILD_ARTIFACTS'])
      dest = File.join(ENV['CC_BUILD_ARTIFACTS'], 'top_output.log')
      max_run_time = 2.hours
      top_interval = 30.seconds
      top_iterations = max_run_time / top_interval
      # top
      # -b batch mode
      # -d delay time between top runs(in seconds)
      # -n number of iterations
      $cc_top_parent_process_id = Process.pid
      system("top -b -d #{top_interval} -n #{top_iterations} >> #{dest} &")
      at_exit { system('killall top') if $cc_top_parent_process_id == Process.pid }
    end
  end
end
