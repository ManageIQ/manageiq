require "active_record"
unless defined? DatabaseConfigurationPatch
  require_relative "../patches/database_configuration_patch.rb"
end

module ManageIQ
  class ActiveRecordConnector
    # Helper class for getting the database config without needing Rails
    #
    # Makes use of the database_configuration_patch for the most part for
    # grabbing this from the yaml file in config/database.yml
    class ConnectionConfig
      # Set a default method for handling super call in
      # lib/patches/database_configuration_patch.rb
      def self.database_configuration
        if ENV["DATABASE_URL"]
          {}
        end
      end

      class << self
        prepend DatabaseConfigurationPatch
      end

      def self.[](env)
        database_configuration[env]
      end
    end

    # Returns true if an ActiveRecord::Base.connection_config is present,
    # otherwise returns false
    def self.connection_exists?
      begin
        true if ActiveRecord::Base.connection_config
      rescue ActiveRecord::ConnectionNotEstablished
        false
      end
    end

    # Establishes a connection if one doesn't already exists.  If a block is
    # passed in, run the code within the block, and then remove the
    # connections that have been made by this method.
    def self.establish_connection_if_needed(db_config, log_path)
      existing_connection = connection_exists?

      unless existing_connection
        ActiveRecord::Base.logger = Logger.new(log_path)
        ActiveRecord::Base.establish_connection(db_config)
      end

      if block_given?
        begin
          yield
        ensure
          ActiveRecord::Base.remove_connection unless existing_connection
        end
      end
    end
  end
end
