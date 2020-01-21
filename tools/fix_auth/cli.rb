require 'optimist'

module FixAuth
  class Cli
    attr_accessor :options

    def parse(args, env = {})
      args.shift if args.first == "--" # Handle when called through script/runner
      self.options = Optimist.options(args) do
        banner "Usage: ruby #{$PROGRAM_NAME} [options] database [...]\n" \
               "       ruby #{$PROGRAM_NAME} [options] -P new_password database [...] to replace all passwords"

        opt :verbose,  "Verbose",           :short => "v"
        opt :dry_run,  "Dry Run",           :short => "d"
        opt :hostname, "Database Hostname", :type => :string,  :short => "h", :default => env['PGHOST']
        opt :port,     "Database Port",     :type => :integer, :default => 5432
        opt :username, "Database Username", :type => :string,  :short => "U", :default => (env['PGUSER'] || "root")
        opt :password, "Database Password", :type => :string,  :short => "p", :default => env['PGPASSWORD']
        opt :hardcode, "Password to use for all passwords",     :type => :string, :short => "P"
        opt :invalid,  "Password to use for invalid passwords", :type => :string, :short => "i"
        opt :key,      "Generate key",      :type => :boolean, :short => "k"
        opt :v2,       "ignored, available for backwards compatibility", :type => :boolean, :short => "f"
        opt :root,     "Rails Root",        :type => :string,  :short => "r",
            :default => (env['RAILS_ROOT'] || File.expand_path(File.join(File.dirname(__FILE__), %w(.. ..))))
        opt :databaseyml, "Rewrite database.yml", :type => :boolean, :short => "y", :default => false
        opt :db,       "Upgrade database",  :type => :boolean, :short => 'x', :default => false
        opt :legacy_key, "Legacy Key",      :type => :string, :short => "K"
        opt :allow_failures, "Run through all records, even with errors", :type => :boolean, :short => nil, :default => false
      end

      options[:database] = args.first || "vmdb_production"
      # default to updating the db
      options[:db] = true if !options[:key] && !options[:databaseyml]
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
