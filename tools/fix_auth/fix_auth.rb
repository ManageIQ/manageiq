require 'manageiq-password'

module FixAuth
  class FixAuth
    # :host, :username, :password, :database
    # :verbose, :dry_run, :hardcode
    attr_accessor :options

    def initialize(args = {})
      self.options = args.delete_if { |_k, v| v.blank? }
      options[:adapter] ||= 'postgresql'
      options[:encoding] ||= 'utf8'
    end

    def verbose?
      options[:verbose]
    end

    def cert_dir
      (options[:root] + "/certs") if options[:root]
    end

    def db_attributes(database)
      options.slice(:adapter, :encoding, :username, :password)
             .merge(:host => options[:hostname], :port => options[:port], :database => database).delete_if { |_k, v| v.blank? }
    end

    def run_options
      options.slice(:verbose, :dry_run, :hardcode, :invalid, :allow_failures)
    end

    def database
      options[:database]
    end

    def models
      [FixAuthentication, FixMiqDatabase, FixMiqAeValue, FixMiqAeField,
       FixSettingsChange, FixMiqRequest, FixMiqRequestTask]
    end

    def generate_password
      ManageIQ::Password.generate_symmetric("#{cert_dir}/v2_key")
    rescue Errno::EEXIST => e
      $stderr.puts
      $stderr.puts "Only generate one encryption_key (v2_key) per installation."
      $stderr.puts "Chances are you did not want to overwrite this file."
      $stderr.puts "If you do this all encrypted secrets in the database will not be readable."
      $stderr.puts "Please backup your key and run again."
      $stderr.puts
      raise Errno::EEXIST, e.message
    end

    def print_dry_run_warning
      method = caller_locations.first.label
      # Move this message up to `run` if the other methods add dry-run support
      puts "** #{method} is executing in dry-run mode, and no actual changes will be made **" if options[:dry_run]
    end

    def fix_database_passwords
      print_dry_run_warning

      begin
        # in specs, this is already setup
        ActiveRecord::Base.connection_config
      rescue ActiveRecord::ConnectionNotEstablished
        # From the command line, we want to connect to a database
        ActiveRecord::Base.logger = Logger.new("#{options[:root]}/log/fix_auth.log")
        ActiveRecord::Base.establish_connection(db_attributes(database))
      end
      models.each do |model|
        model.run(run_options)
      end
    end

    def fix_database_yml
      print_dry_run_warning
      FixDatabaseYml.file_name = "#{options[:root]}/config/database.yml"
      FixDatabaseYml.run({:hardcode => options[:password]}.merge(run_options))
    end

    def load_rails
      require File.expand_path("../../../config/application.rb", __FILE__)
    end

    def set_passwords
      ManageIQ::Password.key_root = cert_dir if cert_dir
      if options[:legacy_key]
        if (legacy_key = ManageIQ::Password.load_key_file(options[:legacy_key]))
          ManageIQ::Password.keys["alt"] = legacy_key
        else
          puts "WARNING: key #{options[:legacy_key]} not found"
        end
      end
    end

    def run
      set_passwords unless options[:key]

      generate_password if options[:key]
      fix_database_yml if options[:databaseyml]
      load_rails if options[:allow_failures]
      fix_database_passwords if options[:db]
    end
  end
end
