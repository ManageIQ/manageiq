require 'awesome_spawn'

module TaskHelpers
  module Development
    module Replication
      REMOTES = [1, 2]
      GLOBAL  = 99
      GUID_FILE   = Rails.root.join("GUID")
      BACKUP_GUID = Rails.root.join("GUID.backup")

      def self.backup
        if File.exist?(guid_file)
          FileUtils.rm_f(backup_guid)
          FileUtils.mv(guid_file, backup_guid)
        end
      end

      def self.restore
        if File.exist?(backup_guid)
          FileUtils.rm_f(guid_file)
          FileUtils.mv(backup_guid, guid_file)
        end
      end

      def self.setup
        REMOTES.each {|r| setup_remote(r) }
        setup_global(GLOBAL)
      end

      def self.setup_remote(region)
        setup_one_region(region)
        setup_remote_region(region)
      end

      def self.setup_global(region)
        setup_one_region(region)
      end

      def self.setup_remote_region(region)
        cmd = "RAILS_ENV='development' DATABASE_URL='#{database_url(region)}' bin/rails r 'MiqRegion.replication_type= :remote; puts MiqRegion.replication_type'"
        puts "Setting up publication #{cmd.inspect}..."
        puts AwesomeSpawn.run!(cmd).output

        psql_cmd = "psql -U root #{database(region)} -c 'select * from pg_publication;'"
        puts AwesomeSpawn.run!(psql_cmd).output
      end

      def self.setup_one_region(region)
        cmd = "REGION='#{region}' RAILS_ENV='development' DATABASE_URL='#{database_url(region)}' DISABLE_DATABASE_ENVIRONMENT_CHECK='true' bin/rails evm:db:region db:seed"
        puts "Running #{cmd.inspect}..."
        puts AwesomeSpawn.run!(cmd).output
      ensure
        FileUtils.rm_f(guid_file)
      end

      def self.database(region)
        "development_replication_#{region}"
      end

      def self.database_url(region)
        "postgres://root:smartvm@localhost:5432/#{database(region)}"
      end

      def self.guid_file
        GUID_FILE
      end

      def self.backup_guid
        BACKUP_GUID
      end
    end
  end
end
