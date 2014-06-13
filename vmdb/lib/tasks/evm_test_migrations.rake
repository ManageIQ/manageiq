namespace :evm do
  namespace :test do
    task :setup_migrations => 'evm:test:initialize' do
      puts "** Preparing migrations database"
      run_rake_via_shell("evm:db:destroy")
    end

    namespace :complete_migrations do
      task :up do
        puts "** Migrating all the way up"
        run_rake_via_shell("db:migrate")
      end

      task :down do
        puts "** Migrating all the way down"
        run_rake_via_shell("db:migrate VERSION=0")
      end
    end
  end
end

def run_rake_via_shell(rake_command)
  cmd = "rake #{rake_command}"
  cmd << " --trace" if Rake.application.options.trace
  pid, status = Process.wait2(Kernel.spawn(cmd, :chdir => Rails.root))
  exit(status.exitstatus) if status.exitstatus != 0
end
