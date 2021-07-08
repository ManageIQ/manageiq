require 'awesome_spawn'

module TaskHelpers
  module Development
    module Replication
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
        setup_remotes
        setup_global
      end

      def self.setup_remotes
        setup_one_region(1)
        setup_one_region(2)
      end

      def self.setup_global
        setup_one_region(99)
      end

      def self.setup_one_region(region)
        database_url = "postgres://root:smartvm@localhost:5432/development_replication_#{region}"
        cmd = "REGION='#{region}' RAILS_ENV='development' DATABASE_URL='#{database_url}' DISABLE_DATABASE_ENVIRONMENT_CHECK='true' bin/rails evm:db:region db:seed"
        puts "Running #{cmd.inspect}..."
        puts AwesomeSpawn.run!(cmd).output
      ensure
        FileUtils.rm_f(guid_file)
      end

      def self.guid_file
        Rails.root.join("GUID")
      end

      def self.backup_guid
        Rails.root.join("GUID.backup")
      end
    end
  end
end
