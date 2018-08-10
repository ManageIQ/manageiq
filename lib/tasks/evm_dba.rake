require 'awesome_spawn'
require 'evm_rake_helper'

# TODO: move into DatabaseYml
# TODO: can we use EvmDatabseOps directly?
module EvmDba
  def self.database_configuration_file
    File.expand_path(File.join(Rails.root, 'config', 'database.yml'))
  end

  def self.load_config
    require 'yaml'
    YAML::load((IO.read(self.database_configuration_file)))
  end

  def self.local?
    config = self.load_config[Rails.env]
    return false unless config['adapter'] == 'postgresql'
    return %w( 127.0.0.1 localhost ).include?(config['host']) || config['host'].blank?
  end
end

namespace :evm do
  namespace :db do
    desc 'Start the local ManageIQ EVM Database (VMDB)'
    task :start do
      LinuxAdmin::Service.new(PostgresAdmin.service_name).start
    end

    desc 'Stop the local ManageIQ EVM Database (VMDB)'
    task :stop do
      LinuxAdmin::Service.new(PostgresAdmin.service_name).stop
    end

    # Start the EVM Database silently - not to be a visible rake task
    task :silent_start do
      begin
        LinuxAdmin::Service.new(PostgresAdmin.service_name).start
      rescue AwesomeSpawn::CommandResultError
        # ignore issues (ala silent)
      end
    end

    # Stop the EVM Database silently - not to be a visible rake task
    task :silent_stop do
      begin
        LinuxAdmin::Service.new(PostgresAdmin.service_name).stop
      rescue AwesomeSpawn::CommandResultError
        # ignore issues (ala silent)
      end
    end

    desc "Seed the ManageIQ EVM Database (VMDB) with defaults"
    task :seed do
      Rake::Task['db:seed'].invoke
    end

    desc "clean up database"
    task :gc do
      require 'trollop'
      opts = Trollop.options(EvmRakeHelper.extract_command_options) do
        opt :username,   "Username",         :type => :string
        opt :password,   "Password",         :type => :string
        opt :hostname,   "Hostname",         :type => :string
        opt :dbname,     "Database name",    :type => :string
        opt :aggressive, "Aggressive gc: vaccume with all options and reindexing"
        opt :vacuum,     "Vacuum database"
        opt :reindex,    "Reindex database (or table if --table specified)"
        opt :analyze,    "Vacuum with analyze"
        opt :full,       "Vacuum full"
        opt :verbose,    "Vacuum with verbose information printed"

        opt :table,      "Tablename to reindex (if only perorm on one)", :type => :string
      end

      opts = opts.delete_if { |_k, v| v.nil? || v == false }
      EvmDatabaseOps.gc(opts)

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    desc "Destroys the ManageIQ EVM Database (VMDB) of all tables, views and indices"
    task :destroy do
      begin
        Rake::Task['environment'].invoke
      rescue => err
        # Allow "destroying" a database that doesn't exist
        raise unless err.message =~ /does not exist$/
      end

      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke

      # db:create creates a temporary connection to the default database, but doesn't
      # remove the connection in the event of a failed create, so we drop the connection
      # and reestablish it to the environment's database.
      ActiveRecord::Base.remove_connection
      ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
    end

    desc "Resets the ManageIQ EVM Database (VMDB) of all tables, views and indices"
    task :reset => [:destroy, 'db:migrate']

    # Example usage:
    #   RAILS_ENV=production bin/rake evm:db:region -- --region 99

    desc 'Set the region of the current ManageIQ EVM Database (VMDB)'
    task :region do
      require 'trollop'
      opts = Trollop.options(EvmRakeHelper.extract_command_options) do
        opt :region, "Region number", :type => :integer, :required => ENV["REGION"].blank?
      end

      Dir.chdir(Rails.root)
      begin
        #TODO: Raise an error if region is not valid
        ENV["REGION"] = opts[:region].to_s if opts[:region]
        region = ENV["REGION"]

        region_file = Rails.root.join("REGION")
        if File.exist?(region_file)
          old_region = File.read(region_file)
          File.delete(region_file)
        end

        puts "Resetting #{Rails.env} database to region #{region}..."
        ENV['VERBOSE'] = 'false' # Do not flood the output with migration details
        Rake::Task['evm:db:reset'].invoke

        puts "Initializing region and database..."
        # Create the region from our REGION file, initialize a new miq_database row for this region
        AwesomeSpawn.run!("bin/rails runner", :params => ["MiqDatabase.seed; MiqRegion.seed"])
      rescue => err
        message = err.kind_of?(AwesomeSpawn::CommandResultError) ? err.result.error : err.message
        STDERR.puts "Encountered issue setting up Database using region #{region}: #{message}\n"
        File.write(region_file, old_region) if old_region
        raise
      end

      exit # exit so that parameters to the first rake task are not run as rake tasks
    end

    # Example usage:
    #   bin/rake evm:db:backup:local -- --local-file /tmp/db_backup_test --dbname vmdb_production
    #   bin/rake evm:db:backup:remote -- --uri smb://dev005.manageiq.com/share1 --uri-username samba_one --uri-password "abc" --remote-file-name region1
    #   bin/rake evm:db:restore:local -- --local-file /tmp/db_backup_test
    #   bin/rake evm:db:restore:remote -- --uri smb://dev005.manageiq.com/share1/db_backup/region1 --uri-username samba_one --uri-password "abc"

    namespace :backup do
      require File.expand_path(File.join(Rails.root, "lib", "evm_database_ops"))
      desc 'Backup the local ManageIQ EVM Database (VMDB) to a local file'
      task :local do
        require 'trollop'
        opts = Trollop.options(EvmRakeHelper.extract_command_options) do
          opt :local_file, "Destination file", :type => :string, :required => true
          opt :username,   "Username",         :type => :string
          opt :password,   "Password",         :type => :string
          opt :hostname,   "Hostname",         :type => :string
          opt :dbname,     "Database name",    :type => :string
        end

        opts.delete_if { |k,v| v.nil? }
        EvmDatabaseOps.backup(opts)

        exit # exit so that parameters to the first rake task are not run as rake tasks
      end

      desc 'Backup the local ManageIQ EVM Database (VMDB) to a remote file'
      task :remote do
        require 'trollop'
        opts = Trollop.options(EvmRakeHelper.extract_command_options) do
          opt :uri,              "Destination depot URI",        :type => :string, :required => true
          opt :uri_username,     "Destination depot username",   :type => :string
          opt :uri_password,     "Destination depot password",   :type => :string
          opt :aws_region,       "Destination depot AWS region", :type => :string
          opt :remote_file_name, "Destination depot filename",   :type => :string
          opt :username,         "Username",                     :type => :string
          opt :password,         "Password",                     :type => :string
          opt :hostname,         "Hostname",                     :type => :string
          opt :dbname,           "Database name",                :type => :string
        end

        db_opts = {}
        [:dbname, :username, :password, :hostname].each { |k| db_opts[k] = opts[k] if opts[k] }

        connect_opts = {}
        [:uri, :uri_username, :uri_password, :aws_region, :remote_file_name].each { |k| connect_opts[k] = opts[k] if opts[k] }
        connect_opts[:username] = connect_opts.delete(:uri_username) if connect_opts[:uri_username]
        connect_opts[:password] = connect_opts.delete(:uri_password) if connect_opts[:uri_password]
        connect_opts[:region]   = connect_opts.delete(:aws_region)   if connect_opts[:aws_region]

        EvmDatabaseOps.backup(db_opts, connect_opts)

        exit # exit so that parameters to the first rake task are not run as rake tasks
      end
    end

    namespace :dump do
      require Rails.root.join("lib", "evm_database_ops").expand_path.to_s
      desc 'Dump the local ManageIQ EVM Database (VMDB) to a local file'
      task :local do
        require 'trollop'
        opts = Trollop.options(EvmRakeHelper.extract_command_options) do
          opt :local_file,           "Destination file",       :type => :string, :required => true
          opt :username,             "Username",               :type => :string
          opt :password,             "Password",               :type => :string
          opt :hostname,             "Hostname",               :type => :string
          opt :dbname,               "Database name",          :type => :string
          opt :"exclude-table-data", "Tables to exclude data", :type => :strings
        end

        opts.delete_if { |_, v| v.nil? }
        EvmDatabaseOps.dump(opts)

        exit # exit so that parameters to the first rake task are not run as rake tasks
      end

      desc 'Dump the local ManageIQ EVM Database (VMDB) to a remote file'
      task :remote do
        require 'trollop'
        opts = Trollop.options(EvmRakeHelper.extract_command_options) do
          opt :uri,                  "Destination depot URI",      :type => :string, :required => true
          opt :uri_username,         "Destination depot username", :type => :string
          opt :uri_password,         "Destination depot password", :type => :string
          opt :remote_file_name,     "Destination depot filename", :type => :string
          opt :username,             "Username",                   :type => :string
          opt :password,             "Password",                   :type => :string
          opt :hostname,             "Hostname",                   :type => :string
          opt :dbname,               "Database name",              :type => :string
          opt :"exclude-table-data", "Tables to exclude data",     :type => :strings
        end

        db_opts = {}
        [:dbname, :username, :password, :hostname, :"exclude-table-data"].each { |k| db_opts[k] = opts[k] if opts[k] }

        connect_opts = {}
        [:uri, :uri_username, :uri_password, :remote_file_name].each { |k| connect_opts[k] = opts[k] if opts[k] }
        connect_opts[:username] = connect_opts.delete(:uri_username) if connect_opts[:uri_username]
        connect_opts[:password] = connect_opts.delete(:uri_password) if connect_opts[:uri_password]

        EvmDatabaseOps.dump(db_opts, connect_opts)

        exit # exit so that parameters to the first rake task are not run as rake tasks
      end
    end

    namespace :restore do
      desc 'Restore the local ManageIQ EVM Database (VMDB) from a local backup file'
      task :local => :environment do
        require 'trollop'
        opts = Trollop.options(EvmRakeHelper.extract_command_options) do
          opt :local_file, "Destination file", :type => :string, :required => true
          opt :username,   "Username",         :type => :string
          opt :password,   "Password",         :type => :string
          opt :hostname,   "Hostname",         :type => :string
          opt :dbname,     "Database name",    :type => :string
        end

        opts.delete_if { |k,v| v.nil? }

        # If running through runner, disconnect any local connections
        ActiveRecord::Base.clear_all_connections! if ActiveRecord && ActiveRecord::Base

        EvmDatabaseOps.restore(opts)

        exit # exit so that parameters to the first rake task are not run as rake tasks
      end

      desc 'Restore the local ManageIQ EVM Database (VMDB) from a remote backup file'
      task :remote => :environment do
        require 'trollop'
        opts = Trollop.options(EvmRakeHelper.extract_command_options) do
          opt :uri,              "Destination depot URI",        :type => :string, :required => true
          opt :uri_username,     "Destination depot username",   :type => :string
          opt :uri_password,     "Destination depot password",   :type => :string
          opt :aws_region,       "Destination depot AWS region", :type => :string
          opt :username,         "Username",                     :type => :string
          opt :password,         "Password",                     :type => :string
          opt :hostname,         "Hostname",                     :type => :string
          opt :dbname,           "Database name",                :type => :string
        end

        db_opts = {}
        [:dbname, :username, :password, :hostname].each { |k| db_opts[k] = opts[k] if opts[k] }

        connect_opts = {}
        [:uri, :uri_username, :uri_password, :aws_region].each { |k| connect_opts[k] = opts[k] if opts[k] }
        connect_opts[:username] = connect_opts.delete(:uri_username) if connect_opts[:uri_username]
        connect_opts[:password] = connect_opts.delete(:uri_password) if connect_opts[:uri_password]
        connect_opts[:region]   = connect_opts.delete(:aws_region)   if connect_opts[:aws_region]

        # If running through runner, disconnect any local connections
        ActiveRecord::Base.clear_all_connections! if ActiveRecord && ActiveRecord::Base

        EvmDatabaseOps.restore(db_opts, connect_opts)

        exit # exit so that parameters to the first rake task are not run as rake tasks
      end
    end

    # loads the v1 key into the enviroment
    task :environmentlegacykey => :environment do
      MiqPassword.add_legacy_key('v0_key', :v0)
      MiqPassword.add_legacy_key('v1_key', :v1)
    end
  end
end

Rake::Task["db:migrate"].enhance(["evm:db:environmentlegacykey"])

Rake::Task["db:reset"].enhance do
  warn "Caution: You ran db:reset which resets the DB from schema.rb. You probably want to re-run all the migrations with the current ruby/rails versions, so run bin/rake evm:db:reset instead."
end
