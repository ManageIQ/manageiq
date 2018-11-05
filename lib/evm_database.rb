class EvmDatabase
  include Vmdb::Logging

  PRIMORDIAL_CLASSES = %w(
    MiqDatabase
    MiqRegion
    MiqEnterprise
    Zone
    MiqServer
    ServerRole
    Tenant
    MiqProductFeature
    MiqUserRole
    MiqGroup
    User
    MiqReport
    VmdbDatabase
  )

  ORDERED_CLASSES = %w(
    RssFeed
    MiqWidget
    MiqAction
    MiqEventDefinitionSet
    MiqEventDefinition
    MiqPolicySet
    ChargebackRateDetailMeasure
    ChargeableField
    ChargebackRateDetailCurrency
    ChargebackRate
  ).freeze

  RAILS_ENGINE_MODEL_CLASS_NAMES = %w(MiqAeDatastore)

  def self.find_seedable_model_class_names
    @found_model_class_names ||= begin
      Dir.glob(Rails.root.join("app/models/*.rb")).collect { |f| File.basename(f, ".*").camelize if File.read(f).include?("self.seed") }.compact.sort
    end
  end

  def self.seedable_model_class_names
    ORDERED_CLASSES + (find_seedable_model_class_names - ORDERED_CLASSES) + RAILS_ENGINE_MODEL_CLASS_NAMES
  end

  def self.seed_primordial
    if ENV['SKIP_SEEDING'] && MiqDatabase.count > 0
      puts "** seedings is skipped on startup."
      puts "** Unset SKIP_SEEDING to re-enable"
    else
      seed(PRIMORDIAL_CLASSES)
    end
  end

  def self.seed_last
    unless ENV['SKIP_SEEDING'] && MiqDatabase.count > 0
      seed(seedable_model_class_names - PRIMORDIAL_CLASSES)
    end
  end

  def self.seed(classes = nil, exclude_list = [])
    _log.info("Seeding...")

    classes ||= PRIMORDIAL_CLASSES + (seedable_model_class_names - PRIMORDIAL_CLASSES)
    classes -= exclude_list

    lock_timeout = (ENV["SEEDING_LOCK_TIMEOUT"].presence || 10.minutes).to_i
    # Only 1 machine can go through this at a time
    MiqDatabase.with_lock(lock_timeout) do
      classes.each do |klass|
        begin
          klass = klass.constantize if klass.kind_of?(String)
        rescue => err
          _log.log_backtrace(err)
          raise
        end

        if klass.respond_to?(:seed)
          _log.info("Seeding #{klass}")
          begin
            klass.seed
          rescue => err
            _log.log_backtrace(err)
            raise
          end
        else
          _log.error("Class #{klass} does not have a seed")
        end
      end
    end

    _log.info("Seeding... Complete")
  rescue Timeout::Error
    _log.error("Timed out seeding database (#{lock_timeout} seconds).")
    raise
  end

  def self.host
    ActiveRecord::Base.configurations.fetch_path(ENV['RAILS_ENV'], 'host')
  end

  def self.local?
    host.blank? || ["localhost", "localhost.localdomain", "127.0.0.1", "0.0.0.0"].include?(host)
  end

  # Determines the average time to the database in milliseconds
  def self.ping(connection = ActiveRecord::Base.connection)
    query = "SELECT 1"
    Benchmark.realtime { 10.times { connection.select_value(query) } } / 10 * 1000
  end

  def self.raise_server_event(event)
    msg = "Server IP: #{MiqServer.my_server.ipaddress}, Server Host Name: #{MiqServer.my_server.hostname}"
    MiqEvent.raise_evm_event_queue(MiqServer.my_server, event, :event_details => msg)
  end

  def self.restart_failover_monitor_service
    service = LinuxAdmin::Service.new("evm-failover-monitor")
    service.restart if service.running?
  end

  def self.restart_failover_monitor_service_queue
    MiqQueue.put(
      :class_name  => name,
      :method_name => 'restart_failover_monitor_service',
      :role        => 'database_operations',
      :zone        => nil
    )
  end

  def self.run_failover_monitor(monitor = nil)
    require 'manageiq-postgres_ha_admin'
    ManageIQ::PostgresHaAdmin.logger = Vmdb.logger

    monitor ||= ManageIQ::PostgresHaAdmin::FailoverMonitor.new(Rails.root.join("config", "ha_admin.yml"))

    configure_rails_handler(monitor)
    configure_pglogical_handlers(monitor)

    _log.info("Starting database failover monitor")
    monitor.monitor_loop
  end

  def self.configure_rails_handler(monitor)
    file_path = Rails.root.join("config", "database.yml")
    rails_handler = ManageIQ::PostgresHaAdmin::RailsConfigHandler.new(:file_path => file_path, :environment => Rails.env)
    _log.info("Configuring database failover for #{file_path}'s #{Rails.env} environment")

    rails_handler.before_failover { LinuxAdmin::Service.new("evmserverd").stop }
    rails_handler.after_failover do
      # refresh the rails connection info after the config handler changed database.yml
      begin
        ActiveRecord::Base.remove_connection
      rescue PG::Error
        # We expect this to fail because it cannot access the database in the cached config
      end
      ActiveRecord::Base.establish_connection(Rails.application.config.database_configuration[Rails.env])

      raise_server_event("db_failover_executed")
      FileUtils.touch(Rails.root.join("tmp", "embedded_ansible_force_setup_run"))
      LinuxAdmin::Service.new("evmserverd").restart
    end

    monitor.add_handler(rails_handler)
  end
  private_class_method :configure_rails_handler

  def self.configure_pglogical_handlers(monitor)
    return unless MiqServer.my_server.has_active_role?("database_operations")

    local_db_conninfo = ActiveRecord::Base.connection.raw_connection.conninfo_hash.delete_blanks
    PglogicalSubscription.all.each do |s|
      handler = ManageIQ::PostgresHaAdmin::PglogicalConfigHandler.new(:subscription => s.id, :conn_info => local_db_conninfo)
      _log.info("Configuring database failover for replication subscription #{s.id} ")

      handler.after_failover do |new_conn_info|
        s.delete
        PglogicalSubscription.new(new_conn_info.slice(:dbname, :host, :user, :password, :port)).save
      end

      monitor.add_handler(handler)
    end
  end
  private_class_method :configure_pglogical_handlers
end
