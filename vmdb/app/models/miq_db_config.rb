class MiqDbConfig
  @@common_options = [
    # note sure if this is required (blank == localhost)
    {:name => :host,     :description => "Hostname",          :required => false},
    {:name => :database, :description => "Database Name",     :required => true},
    {:name => :username, :description => "Username",          :required => true},
    {:name => :password, :description => "Password",          :required => false},
  ]
  @@common_fields = @@common_options.collect {|o| o[:name]}

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

  def initialize(opts={})
    raise "Name option must be provided" unless opts[:name]
    raise "Unknown name [#{opts[:name]}]" unless @@db_types.detect {|t| t[:name] == opts[:name]}

    @options = opts
    @options[:adapter] ||= "postgresql"
  end

  def self.get_db_types
    @@db_types.inject({}) do |h,e|
      h[e[:name]] = e[:description]
      h
    end
  end

  def self.get_db_type_options(name)
    @@common_options
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

  def self.raw_config
    #TODO: We must stringify since ConfigurationEncoder will symbolize on load and stringify on save.
    Vmdb::ConfigurationEncoder.stringify(database_configuration)
  end

  def save
    valid = self.valid?(:from_save => true)
    return @errors unless valid == true

    $log.info("MIQ(DbConfig-save) Validation was successful, saving new settings: #{self.options.merge(@@pwd_mask).inspect}")
    vmdb_config = self.save_without_verify
    MiqRegion.sync_with_db_region(Vmdb::ConfigurationEncoder.stringify(vmdb_config.config))
    return true
  end

  def save_without_verify
    @bkup_ext = Time.now.strftime("%Y%m%d-%H%M%S")
    save_method = "save_#{@options[:name]}"
    save_method = "save_common" unless self.respond_to?(save_method)
    self.send(save_method)
  end

  def save_internal
    self.class.backup_file(@@db_yml, @bkup_ext)
    self.save_common
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
    valid = self.validate_common
    return @errors unless valid == true

    valid = self.verify_config(options[:from_save])
    return valid  ? valid : @errors
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
    return valid
  end

  def self.backup_file(file, ext)
    bkup = "#{file}.#{ext}"
    File.delete(bkup) if File.exist?(bkup)
    require 'fileutils'
    FileUtils.copy(file, bkup)
  end

  def self.human_attribute_name(attribute_key_name, options = {}); attribute_key_name.to_s.humanize; end

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

  def opt_file_for_conn_test(from_save, &blk)
    raise "must pass block" unless block_given?
    opts = self.class.raw_config['production']

    begin
      FileUtils.mkdir_p(File.dirname(DB_FILE))
      File.delete(DB_FILE) if File.exist?(DB_FILE)
      opts[:from_save] = from_save
      File.open(DB_FILE, "wb") {|f|f.write(Base64.encode64(Marshal.dump(opts)))}
      res = yield
    ensure
      File.delete(DB_FILE) if File.exist?(DB_FILE)
    end
    res
  end

  def delete_io_files
    [IO_DOLLAR_STDOUT, IO_DOLLAR_STDERR].each {|f| File.delete(f) if File.exist?(f)}
  end

  def get_output_and_error
    output = File.open(IO_DOLLAR_STDOUT) {|f| f.read} if File.exist?(IO_DOLLAR_STDOUT)
    error_message = File.open(IO_DOLLAR_STDERR) {|f| f.read} if File.exist?(IO_DOLLAR_STDERR)
    return output, error_message
  end

  def verify_config(from_save = nil)
    curr = self.class.current
    $log.info("MIQ(DbConfig-verify_config) Backing up current settings: #{curr.options.merge(@@pwd_mask).inspect}")
    same = self.options == curr.options

    unless same
      $log.info("MIQ(DbConfig-verify_config) Saving new settings: #{self.options.merge(@@pwd_mask).inspect}")
      self.save_without_verify
    end

    @errors ||= ActiveModel::Errors.new(self)
    script = File.join(File.expand_path(Rails.root), "script/verify_db_config.rb")
    begin
      $log.info("MIQ(DbConfig-verify_config) Testing new settings: #{self.options.merge(@@pwd_mask).inspect}")
      delete_io_files
      opt_file_for_conn_test(from_save) { MiqUtil.runcmd("ruby #{script}")}
      output, error_message = get_output_and_error
      output = File.open(IO_DOLLAR_STDOUT) {|f| f.read} if File.exist?(IO_DOLLAR_STDOUT)
      msg = "MIQ(DbConfig-verify_config) Output:\n#{output}"
      msg << "\nError: #{error_message}" if error_message && error_message.length > 0
      $log.info(msg)
    rescue => err
      output, error_message = get_output_and_error
      error_message ||= err.message
      error_message = "of database settings not saved: #{error_message}"
      $log.warn("MIQ(DbConfig-verify_config) Error: #{error_message}\nOutput:\n#{output}")
      @errors.add(:configuration, error_message)
      return false
    ensure
      delete_io_files
      unless same
        $log.info("MIQ(DbConfig-verify_config) Restoring original settings: #{curr.options.merge(@@pwd_mask).inspect}")
        curr.save_without_verify
      end
    end

    return true
  end

  def self.log_statistics
    self.log_activity_statistics
  end

  def self.log_activity_statistics(output = $log)
    require 'csv'

    begin
      stats = PgStatActivity.activity_stats

      keys = stats.first.keys

      csv = CSV.generate do |rows|
        rows << keys
        stats.each do |s|
          vals = s.values_at(*keys)
          rows << vals
        end
      end

      output.info("MIQ(DbConfig.log_activity_statistics) <<-ACTIVITY_STATS_CSV\n#{csv}ACTIVITY_STATS_CSV")
    rescue => err
      output.warn("MIQ(DbConfig.log_activity_statistics) Unable to log stats, '#{err.message}'")
    end
  end
end
