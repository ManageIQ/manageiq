class MiqRubyrep
  def self.filters
    if @filters.nil?
      @filters = []
      Dir.glob(File.join(File.dirname(__FILE__), "rubyrep_filters", "*.rb")) do |f|
        filter = File.basename(f, ".*")
        require File.join("rubyrep_filters", filter)
        @filters << [filter.underscore[0..-8], filter.camelize.constantize]
      end
    end
    @filters
  end

  def self.prepare_configuration(config)
    db_conf = VMDB::Config.new("database").config[Rails.env.to_sym]

    rp_conf = MiqReplicationWorker.worker_settings[:replication]
    raise "Replication configuration missing" if rp_conf.blank?
    if db_conf.slice(:host, :port, :database) == rp_conf.slice(:host, :port, :database)
      raise "Replication configuration source must not point to destination"
    end

    # Local master
    config.left = db_conf.slice(:adapter, :database, :username, :password, :host, :port)
    config.left[:mode] = :master

    # Remote slave
    config.right = rp_conf[:destination].slice(:database, :username, :password, :host, :port)
    config.right[:mode] = :slave
    config.right[:adapter] = config.left[:adapter]

    [:replication_trace, :row_buffer_size, :mem_buffer_size, :commit_frequency, :replication_interval, :database_connection_timeout].each do |setting|
      value = rp_conf.fetch_path(:options, setting)
      value ||= 10000 if setting == :mem_buffer_size
      config.options[setting] = value unless value.nil?
    end

    config.options[:rep_prefix] = "rr#{ActiveRecord::Base.my_region_number}"

    config.options[:replicator]                    = :one_way
    config.options[:syncer]                        = :one_way

    config.options[:adjust_sequences]              = false
    config.options[:auto_key_limit]                = 2
    config.options[:right_change_handling]         = :ignore
    config.options[:left_change_handling]          = :replicate
    config.options[:replication_conflict_handling] = :left_wins
    config.options[:right_record_handling]         = :ignore
    config.options[:left_record_handling]          = :insert
    config.options[:sync_conflict_handling]        = :left_wins

    rp_conf[:include_tables] ||= %w{.+}
    include_tables = rp_conf[:include_tables].to_a.join("|")
    include_tables = "^(#{include_tables})$"
    config.include_tables %r{#{include_tables}}

    rp_conf[:exclude_tables] ||= %w{.+}
    exclude_tables = rp_conf[:exclude_tables].to_a.join("|")
    exclude_tables = "^(#{exclude_tables})$"
    config.exclude_tables %r{#{exclude_tables}}

    filters.each do |table, klass|
      config.add_table_option table, :event_filter => klass.new
    end

    # config.left[:logger]  = Logger.new('rubyrep_left.log')
    # config.right[:logger] = Logger.new('rubyrep_right.log')

    $log.info("Replication Settings:")
    $log.log_hashes({
        :source         => config.left,
        :destination    => config.right,
        :include_tables => include_tables,
        :exclude_tables => exclude_tables,
        :options        => config.options
      })
  end
end
