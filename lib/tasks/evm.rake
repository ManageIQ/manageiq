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
    ENV["DATABASE_URL"] ||= "postgresql://user:pass@127.0.0.1/dbname"
    Rake::Task["assets:clobber"].invoke
    Rake::Task["assets:precompile"].invoke
  end

  task :compile_sti_loader => :environment do
    DescendantLoader.instance.class_inheritance_relationships
  end
end
