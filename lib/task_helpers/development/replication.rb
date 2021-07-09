require 'awesome_spawn'

module TaskHelpers
  module Development
    class Replication
      REMOTES = [1, 2]
      GLOBAL  = 99
      GUID_FILE   = Rails.root.join("GUID")
      BACKUP_GUID = Rails.root.join("GUID.backup")

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
          "development_replication_#{region}"
        end

        def database_url(region)
          "postgres://root:smartvm@localhost:5432/#{database(region)}"
        end

        def guid_file
          GUID_FILE
        end

        def backup_guid
          BACKUP_GUID
        end

        def setup_global_region_script
          host = '127.0.0.1'
          port = '5432'
          user = 'root'
          password = 'smartvm'

          subs = []
          REMOTES.each do |r|
            subs << PglogicalSubscription.new(:host => host, :port => port, :user => user, :dbname => database(r), :password => password)
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
          run_command("psql -U root #{database(region)} -c 'select * from pg_publication;'")
        end

        def setup_one_region(region)
          run_command("#{command_environment(region)} DISABLE_DATABASE_ENVIRONMENT_CHECK='true' bin/rake evm:db:region")
          run_command("#{command_environment(region)} bin/rake db:seed")
        ensure
          FileUtils.rm_f(guid_file)
        end

        def run_command(command)
          puts "Running #{command.inspect}..."
          puts AwesomeSpawn.run!(command).output
        end

        def teardown_global_subscription_for_region(region)
          run_command("psql -U root #{database(GLOBAL)} -c 'drop subscription region_#{region}_subscription;'")
        end

        def teardown_remote_publication(region)
          run_command("psql -U root #{database(region)} -c 'drop publication miq;'")
        end
      end
    end
  end
end
