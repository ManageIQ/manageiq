require 'awesome_spawn'

module TaskHelpers
  module Development
    class Replication
      REMOTES = [1, 2]
      GLOBAL  = 99
      GUID_FILE   = Rails.root.join("GUID")
      BACKUP_GUID = Rails.root.join("GUID.backup")

      PG_USER   = "root"
      PG_PASS   = "smartvm"
      PG_HOST   = "localhost"
      PG_PORT   = "5432"
      DB_PREFIX = "development_replication"

      class << self
        def backup
          if File.exist?(guid_file)
            FileUtils.rm_f(backup_guid)
            FileUtils.mv(guid_file, backup_guid)
          end
        end

        def restore
          if File.exist?(backup_guid)
            FileUtils.rm_f(guid_file)
            FileUtils.mv(backup_guid, guid_file)
          end
        end

        def setup
          REMOTES.each {|r| setup_remote(r) }
          setup_global(GLOBAL)
        end

        def teardown
          REMOTES.each do |r|
            teardown_global_subscription_for_region(r)
            teardown_remote_publication(r)
          end
        end

        def setup_remote(region)
          setup_one_region(region)
          setup_remote_region(region)
        end

        def setup_global(region)
          setup_one_region(region)
          setup_global_region(region)
        end


        def database(region)
          "#{DB_PREFIX}_#{region}"
        end

        def database_url(region)
          "postgres://#{PG_USER}:#{PG_PASS}@#{PG_HOST}:#{PG_PORT}/#{database(region)}"
        end

        def guid_file
          GUID_FILE
        end

        def backup_guid
          BACKUP_GUID
        end

        def setup_global_region_script
          subs = []
          REMOTES.each do |r|
            subs << PglogicalSubscription.new(:host => PG_HOST, :port => PG_PORT, :user => PG_USER, :dbname => database(r), :password => PG_PASS)
          end
          MiqPglogical.save_global_region(subs, [])
        end

        private

        def command_environment(region)
          "REGION='#{region}' RAILS_ENV='development' DATABASE_URL='#{database_url(region)}'"
        end

        def setup_global_region(region)
          run_command("#{command_environment(region)} bin/rails r 'TaskHelpers::Development::Replication.setup_global_region_script'")
        end

        def setup_remote_region(region)
          run_command("#{command_environment(region)} bin/rails r 'MiqRegion.replication_type= :remote; puts MiqRegion.replication_type'")
          run_command("psql -U #{PG_USER} #{database(region)} -c 'select * from pg_publication;'")
        end

        def setup_one_region(region)
          run_command("#{command_environment(region)} DISABLE_DATABASE_ENVIRONMENT_CHECK='true' bin/rake evm:db:region")
          run_command("#{command_environment(region)} bin/rails r 'EvmDatabase.seed_primordial'")
        ensure
          FileUtils.rm_f(guid_file)
        end

        def run_command(command, raise_on_error: true)
          puts "Running #{command.inspect}..."
          puts AwesomeSpawn.run!(command).output
        rescue AwesomeSpawn::CommandResultError => err
          raise if raise_on_error
          puts "Error skipped: #{err.to_s}"
        end

        def teardown_global_subscription_for_region(region)
          run_command("psql -U #{PG_USER} #{database(GLOBAL)} -c 'drop subscription region_#{region}_subscription;'", raise_on_error: false)
        end

        def teardown_remote_publication(region)
          run_command("psql -U #{PG_USER} #{database(region)} -c 'drop publication miq;'", raise_on_error: false)
        end
      end
    end
  end
end
