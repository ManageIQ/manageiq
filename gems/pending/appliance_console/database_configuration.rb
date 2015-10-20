require 'active_record'
require 'active_support/core_ext'
require 'linux_admin'
require 'pathname'
require 'util/miq-password'
require 'fileutils'
require 'appliance_console/errors'
require 'appliance_console/utilities'
require 'appliance_console/logging'

RAILS_ROOT ||= Pathname.new(__dir__).join("../../..")

module ApplianceConsole
  class DatabaseConfiguration
    attr_accessor :adapter, :host, :username, :database, :password, :port, :region

    class ModelWithNoBackingTable < ActiveRecord::Base
    end

    DB_YML      = RAILS_ROOT.join("config/database.yml")
    DB_YML_TMPL = RAILS_ROOT.join("config/database.pg.yml")

    CREATE_REGION_AGREE = "WARNING: Creating a database region will destroy any existing data and cannot be undone.\n\nAre you sure you want to continue? (Y/N):".freeze
    FAILED_WITH_ERROR_HYPHEN = "failed with error -".freeze

    # PG 9.2 bigint max 9223372036854775807 / ArRegion::DEFAULT_RAILS_SEQUENCE_FACTOR = 9223372
    # http://www.postgresql.org/docs/9.2/static/datatype-numeric.html
    # 9223372 won't be a full region though, so we're not including it.
    # TODO: This information should be shared outside of appliance console code and MiqRegion.
    REGION_RANGE = 0..9223371

    include ApplianceConsole::Logging

    def initialize(hash = {})
      initialize_from_hash(hash)
      @adapter ||= "postgresql"
      # introduced by Logging
      self.interactive = true unless hash.key?(:interactive)
    end

    def local?
      host.blank? || host.in?(%w(localhost 127.0.0.1))
    end

    def password=(value)
      @password = MiqPassword.try_decrypt(value)
    end

    def activate
      return false unless validated

      original = self.class.current
      success  = false

      begin
        save
        success = create_or_join_region
      rescue
        success = false
      ensure
        save(original) unless success
      end
    end

    def post_activation
      ServiceGroup.new.restart_services
    end

    def create_or_join_region
      region ? create_region : join_region
    end

    def create_region
      log_and_feedback(__method__) do
        AwesomeSpawn.run!(
          "script/rails runner script/rake",
          :params => ["evm:db:region", "--", {:region => region}],
          :chdir  => RAILS_ROOT
        )
      end
    end

    def join_region
      require 'tempfile'
      temp = Tempfile.new(["joinregion", ".rb"], RAILS_ROOT.join("tmp").to_s)
      params = {nil => ['runner', temp.path]}

      output = nil

      begin
        temp.write(activation_code)
        temp.close

        output = LinuxAdmin.run('script/rails', :chdir => RAILS_ROOT, :params => params).output
      ensure
        temp.delete
      end

      if output.to_s.empty?
        true
      else
        say("\n#{output}") if interactive?
        false
      end
    end

    def create_new_region_questions(warn = true)
      clear_screen
      say(I18n.t("advanced_settings.dbregion_setup"))
      say("\n\nNote: Creating a new database region requires an empty database.") if warn
      say("Each database region number must be unique.\n")
      self.region = ask_for_integer("database region number", REGION_RANGE)
      raise MiqSignalError if warn && !agree(CREATE_REGION_AGREE)
    end

    def ask_for_database_credentials
      self.host     = ask_for_ip_or_hostname("database hostname or IP address", host) if host.blank? || !local?
      self.database = just_ask("name of the database on #{host}", database) unless local?
      self.username = just_ask("username", username) unless local?
      count = 0
      loop do
        count += 1
        password1   = ask_for_password_or_none("database password on #{host}", password)
        # if they took the default, just bail
        break if (password1 == password)
        password2   = ask_for_password("database password again")
        if password1 == password2
          self.password = password1
          break
        elsif count > 1 # only reprompt password once
          raise ArgumentError, "passwords did not match"
        else
          say("\nThe passwords did not match, please try again")
        end
      end
    end

    def friendly_inspect
      output = <<-FRIENDLY
Host:     #{host}
Username: #{username}
Database: #{database}
FRIENDLY
      output << "Region:   #{region}\n" if region
      output
    end

    def settings_hash
      {
        'adapter'  => 'postgresql',
        'host'     => local? ? nil : host,
        'port'     => local? ? nil : port,
        'username' => username,
        'password' => local? ? nil : password.presence,
        'database' => database
      }
    end

    # merge all the non specified setings
    # for all the basic attributes, overwrite from this object (including blank values)
    def merged_settings
      merged = self.class.current
      settings_hash.each do |k, v|
        if v.present?
          merged['production'][k] = v
        else
          merged['production'].delete(k)
        end
      end
      merged
    end

    def save(settings = nil)
      settings ||= merged_settings
      settings = self.class.encrypt_password(settings)
      do_save(settings)
    end

    def self.encrypt_password(settings)
      encrypt_decrypt_password(settings) { |pass| MiqPassword.try_encrypt(pass) }
    end

    def self.decrypt_password(settings)
      encrypt_decrypt_password(settings) { |pass| MiqPassword.try_decrypt(pass) }
    end

    def self.current
      decrypt_password(load_current)
    end

    def self.configured?
      File.exist?(DB_YML)
    end

    def validated
      !!validate!
    rescue => err
      say_error(__method__, err.message)
      log_error(__method__, err.message)
      false
    end

    def validate!
      pool = ModelWithNoBackingTable.establish_connection(settings_hash.delete_if { |_n, v| v.blank? })
      begin
        conn = pool.connection
      ensure
        # Disconnect and remove this new connection from the connection pool, to completely clear it out
        conn.disconnect! if conn
        ActiveRecord::Base.connection_handler.remove_connection(ModelWithNoBackingTable)
      end
    end

    private

    def self.encrypt_decrypt_password(settings)
      new_settings = {}
      settings.each_key { |section| new_settings[section] = settings[section].dup }
      pass = new_settings["production"]["password"]
      new_settings["production"]["password"] = yield(pass) if pass
      new_settings
    end

    def self.load_current
      require 'yaml'
      unless File.exist?(DB_YML)
        require 'fileutils'
        FileUtils.cp(DB_YML_TMPL, DB_YML) if File.exist?(DB_YML_TMPL)
      end
      YAML.load_file(DB_YML)
    end

    def do_save(settings)
      require 'yaml'
      File.write(DB_YML, YAML.dump(settings))
    end

    def initialize_from_hash(hash)
      hash.each do |k, v|
        next if v.nil?
        setter = "#{k}="
        if self.respond_to?(setter)
          public_send(setter, v)
        else
          raise ArgumentError, "Invalid argument: #{k}"
        end
      end
    end

    def activation_code
      code = <<-RUBY
require "#{RAILS_ROOT.join('app/models/miq_db_config')}"

saved = MiqDbConfig.current.save

#TODO: Fix MiqDbConfig.save so it doesn't return truthy values on success and failure
# true => truthy
# an array of ActiveModels::Error objects is also truthy
puts saved.full_messages.join("\\n") unless saved == true
exit 0

RUBY
    end
  end
end
