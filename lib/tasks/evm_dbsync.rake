$:.push(File.dirname(__FILE__))

namespace :evm do
  namespace :dbsync do
    desc "Destroy remote region"
    task :destroy_remote_region => :environment do
      tables = ARGV[1..-1]

      puts "Destroying Remote Region (#{MiqRegion.my_region_number})..."
      t = Time.now
      dest_conf = MiqReplicationWorker.worker_settings.fetch_path(:replication, :destination)
      params = dest_conf.values_at(:host, :port, :username, :password, :database, :adapter)
      unless tables.empty?
        params << tables
        puts "  Only for tables: #{tables.join(", ")}"
      end
      MiqRegionRemote.destroy_entire_region(MiqRegion.my_region_number, *params)
      puts "Destroying Remote Region (#{MiqRegion.my_region_number})...Complete (#{Time.now - t}s)"

      exit if !tables.empty? && $final_rake_task.nil? || $final_rake_task == :destroy_remote_region
    end

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

    desc "Uninstall Rubyrep triggers and tables locally"
    task :local_uninstall => :environment do
      tables = ARGV[1..-1]

      require 'rubyrep'
      puts "Uninstalling Rubyrep locally..."
      t = Time.now
      if tables.empty?
        run_rr_command("uninstall")
      else
        puts "  Only for tables: #{tables.join(", ")}"
        run_rr_command("uninstall_tables", "-t", tables.join(","))
      end
      puts "Uninstalling Rubyrep locally...Complete (#{Time.now - t}s)"

      exit if !tables.empty? && $final_rake_task.nil? || $final_rake_task == :local_uninstall
    end

    desc "Add Rubyrep triggers and tables and do an initial sync"
    task :prepare_replication => :environment do
      require 'rubyrep'
      puts "Preparing Replication in Region (#{MiqRegion.my_region_number})..."
      t = Time.now
      run_rr_command("prepare_replication")
      puts "Preparing Replication in Region (#{MiqRegion.my_region_number})...Complete (#{Time.now - t}s)"

      exit if $final_rake_task && $final_rake_task == :prepare_replication
    end

    desc "Add Rubyrep triggers and tables but don't do an initial sync"
    task :prepare_replication_without_sync => :environment do
      require 'rubyrep'
      puts "Preparing Replication in Region (#{MiqRegion.my_region_number})..."
      t = Time.now
      run_rr_command("prepare_replication", "--no-sync")
      puts "Preparing Replication in Region (#{MiqRegion.my_region_number})...Complete (#{Time.now - t}s)"
    end

    desc "Run Rubyrep replication"
    task :replicate => :environment do
      require 'rubyrep'
      puts "Replicating Region (#{MiqRegion.my_region_number}) to remote database..."
      t = Time.now
      run_rr_command("replicate")
      puts "Replicating Region (#{MiqRegion.my_region_number}) to remote database...Complete (#{Time.now - t}s)"
    end

    desc "Run Rubyrep Replication until the backlog is empty"
    task :replicate_backlog => :environment do
      puts "Replicating Region (#{MiqRegion.my_region_number}) to remote database..."

      unless (total = RrPendingChange.count) == 0
        require 'ruby-progressbar'
        require 'rubyrep'
        pbar = ProgressBar.create(:title => "Backlog", :total => total, :autofinish => false)

        begin
          pid     = Process.spawn("bin/rake evm:dbsync:replicate", :chdir => Rails.root)
          waiting = Thread.new { Process.wait2(pid) }

          # Wait for the Backlog to empty before continuing
          until (count = RrPendingChange.count) == 0
            pbar.progress = (total - count)
            break unless waiting.status
            sleep 1
          end

          puts "Stopping Replication worker..."
        ensure
          begin
            Process.kill("INT", pid)
            sleep(0.1) while waiting.status
          rescue Errno::ESRCH
          end
          pbar.finish
        end
      end

      puts "Current Replication Backlog: #{RrPendingChange.count}"
    end

    desc "Reset Rubyrep installation"
    task :reset do
      $final_rake_task ||= :prepare_replication
      %w{environment evm:dbsync:uninstall evm:dbsync:prepare_replication}.each do |t|
        Rake::Task[t].invoke
      end
    end

    desc "Run Rubyrep sync command"
    task :sync => :environment do
      require 'rubyrep'
      puts "Synchronizing Region (#{MiqRegion.my_region_number}) to remote database..."
      t = Time.now
      run_rr_command("sync")
      puts "Synchronizing Region (#{MiqRegion.my_region_number}) to remote database...Complete (#{Time.now - t}s)"
    end

    desc "Full uninstall of Rubyrep"
    task :uninstall do
      $final_rake_task ||= :local_uninstall
      %w{environment evm:dbsync:destroy_remote_region evm:dbsync:local_uninstall}.each do |t|
        Rake::Task[t].invoke
      end
    end

    #
    # Tasks for bulk syncing
    #

    desc "Run a bulk sync"
    task :sync_bulk => [:environment, :prepare_replication_without_sync, :sync_bulk_started, :sync_bulk_export, :sync_bulk_import, :sync_bulk_complete, :sync_bulk_export_cleanup]

    task :sync_bulk_export => [:environment, :sync_bulk_export_cleanup] do
      puts "Exporting tables for bulk sync..."
      t = Time.now

      db_conf = VMDB::Config.new("database").config[Rails.env.to_sym]
      adapter, database, username, password, host, port = db_conf.values_at(:adapter, :database, :username, :password, :host, :port)

      tables = sync_tables
      puts "Exporting #{tables.join(", ")}..."
      do_pg_copy(:export, tables, database, username, password, host, port)

      puts "Exporting tables for bulk sync...Complete (#{Time.now - t}s)"
    end

    task :sync_bulk_import => :environment do
      puts "Importing tables for bulk sync..."
      t = Time.now

      rp_conf = VMDB::Config.new("vmdb").config.fetch_path(:workers, :worker_base, :replication_worker, :replication)
      database, username, password, host, port = rp_conf[:destination].values_at(:database, :username, :password, :host, :port)
      database, adapter = MiqRegionRemote.prepare_default_fields(database, adapter)

      tables = sync_tables_from_exported_files
      puts "Importing #{tables.join(", ")}..."
      do_pg_copy(:import, tables, database, username, password, host, port)

      puts "Importing tables for bulk sync...Complete (#{Time.now - t}s)"
    end

    task :sync_bulk_export_cleanup do
      require 'fileutils'
      FileUtils.rm_rf(File.join(Rails.root, "tmp", "sync"))
    end

    task :sync_bulk_started => :environment do
      puts "Marking sync state as 'started'..."
      c = ActiveRecord::Base.connection
      c.execute("DELETE FROM rr#{MiqRegion.my_region_number}_sync_state")
      values = sync_tables.collect { |t| "(#{c.quote(t)}, #{c.quote('started')})" }.join(",")
      c.execute("INSERT INTO rr#{MiqRegion.my_region_number}_sync_state (table_name, state) VALUES #{values}") unless values.empty?
      puts "Marking sync state as 'started'...Complete"
    end

    task :sync_bulk_complete => :environment do
      puts "Marking sync state as 'complete'..."
      c = ActiveRecord::Base.connection
      tables = sync_tables_from_exported_files.collect { |t| c.quote(t) }.join(",")
      c.execute("UPDATE rr#{MiqRegion.my_region_number}_sync_state SET state = #{c.quote('complete')} WHERE table_name IN (#{tables})") unless tables.empty?
      puts "Marking sync state as 'complete'...Complete"
    end

    private

    def run_rr_command(*args)
      args += ["-c", File.join(Rails.root, "config", "replication.conf")]
      args.unshift("--verbose")
      exitstatus = RR::CommandRunner.run(args)
      exit(exitstatus) if exitstatus != 0
    end

    def sync_tables
      rp_conf = VMDB::Config.new("vmdb").config.fetch_path(:workers, :worker_base, :replication_worker, :replication)
      ActiveRecord::Base.connection.tables
        .reject { |t| t.start_with?("rr") || rp_conf[:exclude_tables].include?(t) }
        .sort
    end

    def sync_tables_from_exported_files
      Dir.glob(Rails.root.join("tmp/sync/*.sql"))
        .collect { |f| File.basename(f, ".sql") }
        .sort
    end

    # TODO: possible overlap with PostgresAdmin
    def do_pg_copy(direction, tables, database, username, password, host, port)
      dir = File.join(Rails.root, "tmp", "sync")
      FileUtils.mkdir_p(dir)

      cmd_dir = case direction
      when :export then "TO"
      when :import then "FROM"
      end

      cmd = "\\\\COPY"
      password = "PGPASSWORD=#{password}" if password
      password_cleanup = ""

      tables.sort.each do |table|
        file = File.expand_path(File.join(dir, "#{table}.sql"))
        puts "#{direction.to_s.capitalize}ing #{table}"
        `#{password} psql #{"-h #{host}" if host} #{"-p #{port}" if port} -U #{username} -w -d #{database} -c \"#{cmd} #{table} #{cmd_dir} '#{file}' WITH BINARY\" #{password_cleanup}`
      end
    end
  end
end
