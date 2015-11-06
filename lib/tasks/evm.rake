$:.push("#{File.dirname(__FILE__)}")
require 'evm_application'

namespace :evm do
  desc "Start the ManageIQ EVM Application"
  task :start => ["db:verify_local", :environment] do
    EvmApplication.start
  end

  desc "Restart the ManageIQ EVM Application"
  task :restart => ["db:verify_local", :environment] do
    EvmApplication.stop
    EvmApplication.start
  end

  desc "Stop the ManageIQ EVM Application"
  task :stop => :environment do
    EvmApplication.stop
  end

  desc "Kill the ManageIQ EVM Application"
  task :kill => :environment do
    EvmApplication.kill
  end

  desc "Report Status of the ManageIQ EVM Application"
  task :status => :environment do
    EvmApplication.status
  end

  task :update_start do
    EvmApplication.update_start
  end

  task :update_stop => :environment do
    EvmApplication.update_stop
  end

  task :compile_assets do
    with_dummy_database_url_configuration do
      Rake::Task["assets:clobber"].invoke
      Rake::Task["assets:precompile"].invoke
    end
  end

  task :compile_sti_loader do
    with_dummy_database_url_configuration do
      Rake::Task["environment"].invoke
      DescendantLoader.instance.class_inheritance_relationships
    end
  end

  # Loading environment will try to read database.yml unless DATABASE_URL is set.
  # For some rake tasks, the database.yml may not yet be setup and is not required anyway.
  # Note: Rails will not actually use the configuration and connect until you issue a query.
  def with_dummy_database_url_configuration
    before, ENV["DATABASE_URL"] = ENV["DATABASE_URL"], "postgresql://user:pass@127.0.0.1/dbname"
    yield
  ensure
    before.nil? ? ENV.delete("DATABASE_URL") : ENV["DATABASE_URL"] = before
  end
end
