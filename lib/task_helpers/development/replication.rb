require 'uri'

module TaskHelpers
  module Development
    class Replication
      REMOTES = [1, 2].freeze
      GLOBAL  = 99
      GUID_FILE   = Rails.root.join("GUID")
      BACKUP_GUID = Rails.root.join("GUID.backup")

      PG_USER   = "root".freeze
      PG_PASS   = "smartvm".freeze
      PG_HOST   = "localhost".freeze
      PG_PORT   = "5432".freeze
      DB_PREFIX = "development_replication".freeze

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
          REMOTES.each { |r| setup_remote(r) }
          setup_global(GLOBAL)

          # TODO: We have the technology to watch for this and report when it's all good or bad
          puts "Local replication is setup... try checking for users in all regions: psql #{database_url(GLOBAL)} -c \"SELECT id FROM users;\""
        ensure
          restore
        end

        def teardown
          REMOTES.each do |r|
            teardown_global_subscription_for_region(r)
            teardown_remote_publication(r)
          end

          regions = REMOTES + [GLOBAL]
          regions.each do |r|
            run_command("dropdb -U '#{PG_USER}' -h #{PG_HOST} #{database(r)}", env: {"PGPASSWORD" => PG_PASS}, raise_on_error: false)
          end
        end

        def setup_remote(region)
          create_region(region)
          configure_remote_region(region)
        end

        def setup_global(region)
          create_region(region)
          configure_global_region(region)
        end

        def database(region)
          "#{DB_PREFIX}_#{region}"
        end

        # Example: DATABASE_URL='postgres://root:smartvm@localhost:5432/development_replication_99'
        def database_url(region)
          URI::Generic.build(:scheme => "postgres", :host => PG_HOST, :userinfo => "#{PG_USER}:#{PG_PASS}", :port => PG_PORT, :path => "/#{database(region)}").to_s
        end

        def guid_file
          GUID_FILE
        end

        def backup_guid
          BACKUP_GUID
        end

        def configure_global_region_script
          subs = REMOTES.collect do |r|
            PglogicalSubscription.new(:host => PG_HOST, :port => PG_PORT, :user => PG_USER, :dbname => database(r), :password => PG_PASS)
          end
          MiqPglogical.save_global_region(subs, [])
        end

        private

        def command_environment(region)
          {"REGION" => region.to_s, "RAILS_ENV" => "development", "DATABASE_URL" => database_url(region)}
        end

        def configure_global_region(region)
          run_command("bin/rails r 'TaskHelpers::Development::Replication.configure_global_region_script'", env: command_environment(region))
          run_command("psql #{database_url(region)} -c 'SELECT * FROM pg_subscription;'", raise_on_error: false)
        end

        def configure_remote_region(region)
          run_command("bin/rails r 'MiqRegion.replication_type = :remote'", env: command_environment(region))
          run_command("psql #{database_url(region)} -c 'SELECT * FROM pg_publication;'")
        end

        def create_region(region)
          run_command("bin/rake evm:db:region", env: command_environment(region).merge("DISABLE_DATABASE_ENVIRONMENT_CHECK" => "true"))
          run_command("bin/rails r 'EvmDatabase.seed_primordial'", env: command_environment(region))
        ensure
          FileUtils.rm_f(guid_file)
        end

        def run_command(command, raise_on_error: true, env: {})
          puts "\e[32m** #{command.inspect} with env: #{env.inspect}...\e[0m"
          success = system(env, command)
          puts
          unless success
            if raise_on_error
              puts "\e[31mAn error occurred during execution!\e[0m"
              raise
            else
              puts "\e[33mAn error occurred during execution...skipping\e[0m"
            end
            puts
          end
        end

        def teardown_global_subscription_for_region(region)
          run_command("psql #{database_url(GLOBAL)} -c 'DROP SUBSCRIPTION region_#{region}_subscription;'", raise_on_error: false)
        end

        def teardown_remote_publication(region)
          run_command("psql #{database_url(region)} -c 'DROP PUBLICATION miq;'", raise_on_error: false)
        end
      end
    end
  end
end
