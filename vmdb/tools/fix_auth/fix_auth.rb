require 'util/miq-password'

module FixAuth
  class FixAuth
    # :host, :username, :password, :databases
    # :verbose, :dry_run, :hardcode
    attr_accessor :options

    def initialize(args = {})
      self.options = args.delete_if { |_k, v| v.blank? }
      options[:adapter]  ||= 'postgresql'
      options[:encoding] ||= 'utf8'
    end

    def verbose?
      options[:verbose]
    end

    def cert_dir
      options[:root] ? options[:root] + "/certs" : nil
    end

    def db_attributes(database)
      options.slice(:adapter, :encoding, :username, :password)
        .merge(:host => options[:hostname], :database => database).delete_if { |_k, v| v.blank? }
    end

    def run_options
      options.slice(:verbose, :dry_run, :hardcode, :invalid, :v2)
    end

    def databases
      options[:databases]
    end

    def models
      [FixAuthentication, FixMiqDatabase, FixMiqAeValue, FixMiqAeField, FixConfiguration,
       FixMiqRequest, FixMiqRequestTask]
    end

    def generate_password
      MiqPassword.backup_symetric("#{cert_dir}/v2_key")
      MiqPassword.generate_symmetric("#{cert_dir}/v2_key")
    end

    def fix_database_passwords
      begin
        ActiveRecord::Base.connection_config
      rescue ActiveRecord::ConnectionNotEstablished
        # not configured, lets try again
        ActiveRecord::Base.logger = Logger.new("#{options[:root]}/log/fix_auth.log")
        please_establish_connection = true
      end
      databases.each do |database|
        begin
          ActiveRecord::Base.establish_connection(db_attributes(database)) if please_establish_connection
          models.each do |model|
            puts "fixing #{model.table_name}.#{model.password_columns.join(", ")}"
            model.run(run_options)
          end
        ensure
          ActiveRecord::Base.clear_active_connections! if please_establish_connection
        end
      end
    end

    def run
      MiqPassword.key_root = cert_dir if cert_dir
      generate_password if options[:key]
      fix_database_passwords
    end
  end
end
