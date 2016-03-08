class MiqDbConfig
  include Vmdb::Logging
  @@common_options = [
    # note sure if this is required (blank == localhost)
    {:name => :host,     :description => "Hostname",          :required => false},
    {:name => :database, :description => "Database Name",     :required => true},
    {:name => :username, :description => "Username",          :required => true},
    {:name => :password, :description => "Password",          :required => false},
  ]
  @@common_fields = @@common_options.collect { |o| o[:name] }

  @@db_types = [
    {:name => "internal",     :description => "Internal Database on this CFME Appliance"},
    {:name => "external_evm", :description => "External Database on another CFME Appliance"},
    {:name => "postgresql",   :description => "External Postgres Database"}
  ]

  @@defaults = {
    :adapter      => "postgresql",
    :username     => "root",
    :database     => "vmdb_production",
    :encoding     => "utf8",
    :pool         => 5,
    :wait_timeout => 5
  }

  @@cfg_dir  = File.join(Rails.root, "config")
  @@db_yml   = File.join(@@cfg_dir, "database.yml")

  @@pwd_mask = {:password => "[PASSWORD]", :verify => "[PASSWORD]"}

  DB_FILE = File.join(Rails.root, "data/db_settings")
  IO_DOLLAR_STDOUT = File.join(Rails.root, "data/verify_db_dollar_stdout")
  IO_DOLLAR_STDERR = File.join(Rails.root, "data/verify_db_dollar_stderr")

  cattr_accessor :db_types
  attr_accessor  :options, :errors

  def initialize(opts = {})
    raise "Name option must be provided" unless opts[:name]
    raise "Unknown name [#{opts[:name]}]" unless @@db_types.detect { |t| t[:name] == opts[:name] }

    @options = opts
    @options[:adapter] ||= "postgresql"
  end

  def self.get_db_types
    @@db_types.inject({}) do |h, e|
      h[e[:name]] = e[:description]
      h
    end
  end

  def self.database_configuration
    VMDB::Config.new("database").config
  end

  def self.current
    chash = copy_hash(database_configuration)[:production]
    new(chash.merge(:name => determine_name(chash)))
  end

  def self.determine_name(opts)
    if opts[:database] != "vmdb_production"
      opts[:adapter]
    elsif opts[:host].in?([nil, "", "localhost", "127.0.0.1"])
      "internal"
    else
      "external_evm"
    end
  end

  def save
    valid = self.valid?(:from_save => true)
    return @errors unless valid == true

    _log.info("Validation was successful, saving new settings: #{options.merge(@@pwd_mask).inspect}")
    vmdb_config = save_without_verify
    MiqRegion.sync_with_db_region(vmdb_config.config)
    true
  end

  def save_without_verify
    @bkup_ext = Time.now.strftime("%Y%m%d-%H%M%S")
    save_method = "save_#{@options[:name]}"
    save_method = "save_common" unless self.respond_to?(save_method)
    send(save_method)
  end

  def save_internal
    self.class.backup_file(@@db_yml, @bkup_ext)
    save_common
  end

  def save_common
    current = VMDB::Config.new("database")
    self.class.backup_file(@@db_yml, @bkup_ext)

    [:development, :production].each do |env|
      current.config[env] = @@defaults.merge(@options).delete_if { |n, _v| n == :name }
    end
    current.save_file(@@db_yml)
    current.update_cache_metadata
    current
  end

  def valid?(options = {})
    valid = validate_common
    return @errors unless valid == true

    valid = verify_config(options[:from_save])
    valid ? valid : @errors
  end

  def validate; self.valid?; end

  def validate_common
    return true if @options[:name] == "internal"

    @errors = ActiveModel::Errors.new(self)
    valid = true
    @@common_options.each do |fld|
      next if fld[:required] != true
      if @options[fld[:name]].blank?
        @errors.add(:field, "'#{fld[:description]}' is required")
        valid = false
        next
      end

      if fld[:numeric] == true && !is_numeric?(@options[fld[:name]])
        @errors.add(:field, "'#{fld[:description]}' must be a numeric")
        valid = false
      end
    end
    valid
  end

  def self.backup_file(file, ext)
    bkup = "#{file}.#{ext}"
    File.delete(bkup) if File.exist?(bkup)
    require 'fileutils'
    FileUtils.copy(file, bkup)
  end

  def self.human_attribute_name(attribute_key_name, _options = {}); attribute_key_name.to_s.humanize; end

  def method_missing(m, *args)
    if m.to_s.ends_with?("=")
      attr = m.to_s.split("=").first.to_sym
      mode = :set
    else
      attr = m
      mode = :get
    end

    unless @@common_fields.include?(attr) || attr == :adapter
      super
      return
    end

    attr = :name if attr == :adapter

    case mode
    when :get then return @options[attr]
    when :set then @options[attr] = *args
    end
  end

  def verify_config(from_save = nil)
    @errors = ActiveModel::Errors.new(self)

    with_temporary_connection do |conn|
      tables = conn.tables

      # If we're not saving, return only if we were able to issue a query or not
      return !!tables unless from_save

      if tables.empty?
        _log.info("No migrations have been run... migrating")
        ActiveRecord::Tasks::DatabaseTasks.migrate
        true
      else
        _log.info("#{conn.tables} tables exist")
        pending_count = pending_migrations.length
        if pending_count == 0
          true
        else
          msg = "The requested database is not empty and has #{pending_count} migrations to apply."
          _log.error("Error: #{msg}")
          @errors.add(:configuration, msg)
          false
        end
      end
    end
  rescue => err
    _log.error("Error: #{err}")
    @errors.add(:configuration, err.message)
    false
  end

  private

  def with_temporary_connection
    config_hash = options.stringify_keys

    config_before     = ActiveRecord::Tasks::DatabaseTasks.database_configuration
    connection_before = ActiveRecord::Base.remove_connection

    ActiveRecord::Tasks::DatabaseTasks.database_configuration = {Rails.env => config_hash}
    conn = ActiveRecord::Base.establish_connection(config_hash).connection
    yield conn
  ensure
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = config_before
    ActiveRecord::Base.remove_connection
    ActiveRecord::Base.establish_connection(connection_before)
  end

  def pending_migrations
    ActiveRecord::Migrator.open(ActiveRecord::Tasks::DatabaseTasks.migrations_paths).pending_migrations
  end
end
