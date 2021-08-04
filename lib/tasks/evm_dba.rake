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

  def self.with_options(*option_types, &block)
    require 'optimist'

    Optimist.options(EvmRakeHelper.extract_command_options) do
      option_types.each do |type|
        case type
        when :db_credentials
          opt :username,           "Username",                     :type => :string
          opt :password,           "Password",                     :type => :string
          opt :hostname,           "Hostname",                     :type => :string
          opt :port,               "Port",                         :type => :string
          opt :dbname,             "Database name",                :type => :string
        when :local_file
          opt :local_file,         "Destination file",             :type => :string, :required => true
        when :remote_file
          opt :skip_directory,     "Don't add backup directory",   :type => :boolean, :default => false
          opt :remote_file_name,   "Destination depot filename",   :type => :string
        when :splitable
          opt :byte_count,         "Size to split files into",     :type => :string
        when :remote_uri
          opt :uri,                "Destination depot URI",        :type => :string, :required => true
          opt :uri_username,       "Destination depot username",   :type => :string
          opt :uri_password,       "Destination depot password",   :type => :string
        when :aws
          opt :aws_region,         "Destination depot AWS region", :type => :string
        when :exclude_table_data
          opt :exclude_table_data, "Tables to exclude data",       :type => :strings
        end
      end
      instance_exec(&block) if block_given?
    end.delete_nils
  end

  DB_OPT_KEYS = [:dbname, :username, :password, :hostname, :port, :exclude_table_data, :byte_count].freeze
  def self.collect_db_opts(opts)
    db_opts = {}
    DB_OPT_KEYS.each { |k| db_opts[k] = opts[k] if opts[k] }
    db_opts
  end

  CONNECT_OPT_KEYS = %i(uri uri_username uri_password aws_region remote_file_name skip_directory).freeze
  def self.collect_connect_opts(opts)
    connect_opts = {}
    CONNECT_OPT_KEYS.each { |k| connect_opts[k] = opts[k] if opts[k] }
    connect_opts[:username] = connect_opts.delete(:uri_username) if connect_opts[:uri_username]
    connect_opts[:password] = connect_opts.delete(:uri_password) if connect_opts[:uri_password]
    connect_opts
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

    # schema.rb doesn't support views which is used by metrics
    task :db_setup_not_supported do
      warn "db:setup and db:reset are not supported! Please use evm:db:reset, db:migrate, or test:vmdb:setup instead."
      exit 1
    end

    # Example usage:
    #   RAILS_ENV=production bin/rake evm:db:region -- --region 99

    desc 'Set the region of the current ManageIQ EVM Database (VMDB)'
    task :region do
      opts = EvmDba.with_options do
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
  end
end

Rake::Task["db:setup"].prerequisites.unshift("evm:db:db_setup_not_supported")
Rake::Task["db:reset"].prerequisites.unshift("evm:db:db_setup_not_supported")
