namespace :test do
  task :setup_db do
    ENV['RAILS_ENV'] ||= "test"
    Rails.env = ENV['RAILS_ENV'] if defined?(Rails)

    ENV['VERBOSE']   ||= "false"
    Rake::Task['evm:db:reset'].invoke
  end

  task :setup_vmdb        => :setup_db
  task :setup_migrations  => :setup_db
  task :setup_replication => 'evm:test:setup_replication'
  task :setup_automation  => :setup_db

  desc "Runs all specs except migrations, replication, automation, and requests"
  task :vmdb        => 'spec:evm:backend'

  desc "Runs all migration specs"
  task :migrations  => ['spec:evm:migrations:down', 'evm:test:complete_migrations:down', 'spec:evm:migrations:up', 'evm:test:complete_migrations:up']

  desc "Runs all replication specs"
  task :replication => 'spec:evm:replication'

  desc "Runs all automation specs"
  task :automation  => 'spec:evm:automation'
end

task :default => 'test:vmdb'
