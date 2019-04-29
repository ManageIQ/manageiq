$:.push(File.dirname(__FILE__))

namespace :evm do
  namespace :dbsync do
    desc "Remove remote region data from local database"
    task :destroy_local_region => :environment do
      region_number = ARGV[1].to_i

      if region_number == MiqRegion.my_region_number
        puts "Refusing to destroy local region #{MiqRegion.my_region_number}"
      else
        puts "Destroying region #{region_number} ..."
        MiqRegion.destroy_region(ApplicationRecord.connection, region_number)
        puts "Destroying region #{region_number} ... Complete"
      end

      exit if $final_rake_task.nil? || $final_rake_task == :destroy_local_region
    end

    desc "Resync excluded tables"
    task :resync_excludes => :environment do
      require 'application_record' unless defined?(ApplicationRecord)
      require 'miq_pglogical'
      pgl = MiqPglogical.new
      pgl.refresh_excludes if pgl.provider?
      PglogicalSubscription.all.each(&:sync_tables)
    end
  end
end

# Always run evm:dbsync:resync_excludes after migrations
namespace :db do
  task :migrate do
    if !defined?(ENGINE_ROOT)
      Rake::Task['evm:dbsync:resync_excludes'].invoke
    else
      Rake::Task['app:evm:dbsync:resync_excludes'].invoke
    end
  end
end
