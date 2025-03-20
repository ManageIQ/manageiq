require 'optimist'

module FixAuth
  class Cli
    attr_accessor :options

    def parse(args, env = {})
      args.shift if args.first == "--" # Handle when called through script/runner
      self.options = Optimist.options(args) do
        banner "Usage: #{File.basename($PROGRAM_NAME)} [options] database            # to migrate from a different or lost key\n" \
               "       #{File.basename($PROGRAM_NAME)} -P new_password --databaseyml # to fix database.yml\n" \
               "       #{File.basename($PROGRAM_NAME)} --key                         # to generate a new certs/v2_key "

        opt :verbose,  "Verbose",           :short => "v"
        opt :dry_run,  "Dry Run",           :short => "d"
        opt :hostname, "Database Hostname", :type => :string,  :short => "h", :default => env['PGHOST']
        opt :port,     "Database Port",     :type => :integer, :default => 5432
        opt :username, "Database Username", :type => :string,  :short => "U", :default => (env['PGUSER'] || "root")
        opt :password, "Database Password", :type => :string,  :short => "p", :default => env['PGPASSWORD']
        opt :hardcode, "Password used to replace all passwords", :type => :string, :short => "P"
        opt :invalid,  "Password used to replace non-decryptable passwords", :type => :string, :short => "i"
        opt :key,      "Generate encryption key", :type => :boolean, :short => "k"
        opt :v2,       "ignored, available for backwards compatibility", :type => :boolean, :short => "f"
        opt :root,     "Rails Root",        :type => :string,  :short => "r",
            :default => (env['RAILS_ROOT'] || File.expand_path(File.join(File.dirname(__FILE__), %w[.. ..])))
        opt :databaseyml, "Fix database.yml", :type => :boolean, :short => "y", :default => false
        opt :db,       "Upgrade database",  :type => :boolean, :short => 'x', :default => false
        opt :legacy_key, "Key used to decrypt old passwords when migrating to new key", :type => :string, :short => "K"
        opt :allow_failures, "Run through all records, even with errors", :type => :boolean, :short => nil, :default => false
      end

      # default to updating the db
      options[:db] = true if !options[:key] && !options[:databaseyml]

      # When converting the database, require database name
      # When RAILS_ENV specified (aka on the appliance) default to production db
      Optimist::die "please specify a database as an argument" if args.empty? && ENV["RAILS_ENV"].nil? && options[:db]

      # default to updating 
      options[:database] = args.first || "vmdb_production"
      self.options = options.delete_if { |_n, v| v.blank? }
      self
    end

    def run
      ::FixAuth::FixAuth.new(options).run
    end

    def self.run(args, env = {})
      new.parse(args, env).run
    end
  end
end
