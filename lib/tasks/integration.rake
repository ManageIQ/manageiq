namespace :integration do
  desc "Seed the database and configure assets for integration tests"
  task :seed => ['seed:all']

  namespace :seed do
    task :all    => [:db, :assets]
    task :db     => [:env, "test:vmdb:setup", "evm:foreman:seed", :setup_db_cleaner]
    task :assets => [:env, "test:initialize", :compile_assets]

    # Internal task:  call via integration:seed:db
    task :setup_db_cleaner => :load_manager do
      puts "Setting up ManageIQ::Integration::DatabaseCleaner..."
      ManageIQ::Integration::DatabaseCleaner.setup!(force: true)
    end

    task :compile_assets do |rake_task|
      app_prefix = rake_task.name.chomp('integration:seed:compile_assets')
      if ENV["CYPRESS_DEV"]
        Rake::Task["#{app_prefix}update:ui"].invoke
      else
        Rake::Task["#{app_prefix}evm:compile_assets"].invoke
      end
    end
  end

  desc "Setup the database for integration tests"
  task :setup => [:db_setup, "evm:foreman:setup"] do
    ManageIQ::Integration::ForemanManager.setup
  end

  desc "Run a foreman server in the background for integration tests"
  task :run_server => [:setup] do
    ManageIQ::Integration::ForemanManager.run
  end

  desc "Start and wait for an integration server to boot"
  task :start_server => [:run_server, :ui_ready] do
    MiqServer.my_server.update(:status => "started")
  end

  desc "Stop server for integration tests"
  task :stop_server => [:load_manager] do
    ManageIQ::Integration::ForemanManager.stop
  end

  desc "Status of the currently running process"
  task :server_status => [:load_manager] do
    ManageIQ::Integration::ForemanManager.status
  end

  # Check if a UI worker is running
  task :ui_ready => :run_server do
    ManageIQ::Integration::ForemanManager.ui_running?
  end

  # For tasks that don't need the full Rails ENV, but need the
  # ManageIQ::Integration file loaded (:stop_server).
  task :load_manager do
    require File.expand_path(File.join("..", "manageiq", "integration"), __dir__)
  end

  task :env do
    ENV["RAILS_ENV"] = "integration"
    ENV["RAILS_SERVE_STATIC_FILES"] = "true"
    Rails.env = ENV["RAILS_ENV"] if defined?(Rails)
  end

  task :db_setup => [:env, :environment] do
    # Reset Rails.env and database config to make sure we are using the
    # integration environment
    Rails.env = ENV["RAILS_ENV"]
    ActiveRecord::Base.remove_connection
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
  end
end
