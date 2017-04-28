namespace :evm do
  desc "Start the ManageIQ EVM Application"
  task :start => :evm_app_init do
    Mini::MiqServer.with_temporary_connection { EvmApplication.start }
    puts "Mem: #{((1024 * BigDecimal.new(`ps -o rss= -p #{Process.pid}`))/BigDecimal.new(1_048_576)).to_f}MiB"
  end

  desc "Restart the ManageIQ EVM Application"
  task :restart => :evm_app_init  do
    EvmApplication.stop
    EvmApplication.start
  end

  desc "Stop the ManageIQ EVM Application"
  task :stop => :evm_app_init do
    Mini::MiqServer.with_temporary_connection { EvmApplication.stop }
    puts "Mem: #{((1024 * BigDecimal.new(`ps -o rss= -p #{Process.pid}`))/BigDecimal.new(1_048_576)).to_f}MiB"
  end

  desc "Kill the ManageIQ EVM Application"
  task :kill => :environment do
    EvmApplication.kill
  end

  desc "Report Status of the ManageIQ EVM Application"
  task :status => :evm_app_init do
    Mini::MiqServer.with_temporary_connection { EvmApplication.status }
    puts "Mem: #{((1024 * BigDecimal.new(`ps -o rss= -p #{Process.pid}`))/BigDecimal.new(1_048_576)).to_f}MiB"
  end

  desc "Report Status of the ManageIQ EVM Application"
  task :status_full => :evm_app_init do
    Mini::MiqServer.with_temporary_connection { EvmApplication.status(true) }
    puts "Mem: #{((1024 * BigDecimal.new(`ps -o rss= -p #{Process.pid}`))/BigDecimal.new(1_048_576)).to_f}MiB"
  end

  desc "Write a remote region id to this server's REGION file"
  task :join_region => :environment do
    configured_region = ApplicationRecord.region_number_from_sequence.to_i
    EvmApplication.set_region_file(Rails.root.join("REGION"), configured_region)
  end

  # update_start can be called in an environment where the database configuration is
  # not set, so we need to give it a dummy config
  desc "Start updating the appliance"
  task :update_start => :evm_app_init do
    EvmRakeHelper.with_dummy_database_url_configuration do
      Rake::Task["environment"].invoke
      EvmApplication.update_start
    end
  end

  desc "Stop updating the appliance"
  task :update_stop => :environment do
    EvmApplication.update_stop
  end

  task :compile_assets => 'evm:assets:compile'
  namespace :assets do
    desc "Compile assets (clobber and precompile)"
    task :compile do
      EvmRakeHelper.with_dummy_database_url_configuration do
        Rake::Task["assets:clobber"].invoke
        Rake::Task["assets:precompile"].invoke
      end
    end
  end

  desc "Compile STI inheritance relationship cache"
  task :compile_sti_loader do
    unless defined? Vmdb::Application
      require File.expand_path('../../../config/application', __FILE__)
      Vmdb::Application.load_tasks
    end

    EvmRakeHelper.with_dummy_database_url_configuration do
      Rake::Task["environment"].invoke
      DescendantLoader.instance.class_inheritance_relationships
    end
  end

  # Example usage:
  #  bin/rake evm:raise_server_event -- --event db_failover_executed
  desc 'Raise evm event'
  task :raise_server_event => :environment do
    require 'trollop'
    opts = Trollop.options(EvmRakeHelper.extract_command_options) do
      opt :event, "Server Event", :type => :string, :required => true
    end
    EvmDatabase.raise_server_event(opts[:event])
  end

  # FIXME:
  # Currently, there is a decent amount of hacks in place to allow the code
  # reuse for the `Mini::` classes defined in the `tools/utils` dir.  These end
  # up getting loaded prior to app/models/ counter parts, and mess up
  # autoloading because of it.
  #
  # To avoid that, only require the `EvmApplication` model when a task needs it
  # to prevent it from loading when we do non-evm based rake tasks.
  task :evm_app_init do
    $:.push(File.dirname(__FILE__))
    require 'evm_application'
  end
end
