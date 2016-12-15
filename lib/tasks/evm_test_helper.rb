module EvmTestHelper
  VMDB_EXCLUDED_SPEC_DIRECTORIES = %w(replication migrations).freeze
  MIGRATION_SPECS        = FileList['spec/migrations/**/*_spec.rb'].sort
  UI_SPECS               = Manageiq::Ui.rspec_paths

  def self.init_rspec_task(t, rspec_opts = [])
    if ENV['CI']
      rspec_ci = defined?(ENGINE_ROOT) ? File.join(ENGINE_ROOT, ".rspec_ci") : Rails.root.join(".rspec_ci")
      rspec_opts.unshift('--options', rspec_ci)
    end
    t.rspec_opts = rspec_opts
    t.verbose = false
  end

  def self.run_rake_via_shell(rake_command, env = {})
    cmd = "bundle exec rake #{rake_command}"
    cmd << " --trace" if Rake.application.options.trace
    _pid, status = Process.wait2(Kernel.spawn(env, cmd, :chdir => Rails.root))
    exit(status.exitstatus) if status.exitstatus != 0
  end

  def self.vmdb_spec_directories
    # TODO: Clean up this thing
    #
    # Within the spec directory, find:
    #  * directories
    #  * that aren't automation/migrations/replication (the excluded directories)
    #  * that contain *_spec.rb files
    #
    # This is required because parallel_tests takes directories
    # RSpec will sort out the parsing of _spec.rb's within them, too!
    #
    # Output: %w(./spec/controllers ./spec/helpers ./spec/initializers ..)
    Dir.glob("./spec/*").select do |d|
      File.directory?(d) &&
        !EvmTestHelper::VMDB_EXCLUDED_SPEC_DIRECTORIES.include?(File.basename(d)) &&
        !Dir.glob("#{d}/**/*_spec.rb").empty?
    end
  end
end
