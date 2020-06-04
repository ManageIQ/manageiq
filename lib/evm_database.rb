class EvmDatabase
  include Vmdb::Logging

  # A ordered list of classes that are seeded before server initialization.
  PRIMORDIAL_SEEDABLE_CLASSES = %w[
    MiqDatabase
    MiqRegion
    MiqEnterprise
    Zone
    MiqServer
    ServerRole
    MiqWorkerType
    Tenant
    MiqProductFeature
    MiqUserRole
    MiqGroup
    User
    MiqReport
  ].freeze

  # An ordered list of classes that will complete the seeding, but occuring
  # after server initialization.
  OTHER_SEEDABLE_CLASSES = %w[
    MiqWidget
    MiqAction
    MiqEventDefinitionSet
    MiqEventDefinition
    MiqPolicySet
    ChargebackRateDetailMeasure
    ChargeableField
    Currency
    ChargebackRate

    BlacklistedEvent
    Classification
    CustomizationTemplate
    Dialog
    ManageIQ::Providers::EmbeddedAnsible
    MiqAlert
    MiqAlertSet
    MiqDialog
    MiqSearch
    MiqShortcut
    MiqWidgetSet
    NotificationType
    PxeImageType
    ScanItem
    TimeProfile

    MiqAeDatastore
  ].freeze

  def self.seedable_classes
    PRIMORDIAL_SEEDABLE_CLASSES + OTHER_SEEDABLE_CLASSES + seedable_plugin_classes
  end

  def self.seedable_plugin_classes
    Vmdb::Plugins.flat_map { |p| p.try(:seedable_classes) }.compact
  end

  def self.seed(classes = nil, exclude_list = [])
    classes ||= seedable_classes
    classes  -= exclude_list
    classes   = classes.collect(&:constantize)

    invalid = classes.reject { |c| c.respond_to?(:seed) }
    raise ArgumentError, "class(es) #{invalid.join(", ")} do not respond to seed" if invalid.any?

    seed_classes(classes)
  end

  def self.seed_primordial
    if skip_seeding?
      puts "** Seeding is skipped on startup. Unset SKIP_SEEDING to re-enable" # rubocop:disable Rails/Output
      return
    end

    seed(PRIMORDIAL_SEEDABLE_CLASSES)
  end

  def self.seed_rest
    return if skip_seeding?
    seed(OTHER_SEEDABLE_CLASSES + seedable_plugin_classes)
  end

  # Returns whether or not a primordial seed has completed.
  def self.seeded_primordially?
    # While not technically accurate, as someone could just insert a record
    # directly, this is the simplest check at the moment to guess whether or not
    # a primordial seed has completed.
    MiqDatabase.any? && MiqRegion.in_my_region.any?
  end

  # Returns whether or not a full seed has completed.
  def self.seeded?
    # While not technically accurate, as someone could just insert a record
    # directly, this is the simplest check at the moment to guess whether or not
    # a full seed has completed.
    #
    # MiqAction was chosen because it cannot be added by a user directly.
    seeded_primordially? && MiqAction.in_my_region.any?
  end

  def self.skip_seeding?
    ENV['SKIP_SEEDING'] && seeded_primordially?
  end
  private_class_method :skip_seeding?

  def self.seed_classes(classes)
    _log.info("Seeding...")

    lock_timeout = (ENV["SEEDING_LOCK_TIMEOUT"].presence || 10.minutes).to_i

    total = Benchmark.ms do
      # Only 1 machine can go through this at a time
      MiqDatabase.with_lock(lock_timeout) do
        classes.each do |c|
          _log.info("Seeding #{c}...")
          ms = Benchmark.ms { c.seed }
          _log.info("Seeding #{c}... Complete in #{ms}ms")
        end
      end
    end

    _log.info("Seeding... Complete in #{total}ms")
  rescue Timeout::Error
    _log.error("Seeding... Timed out after #{lock_timeout} seconds")
    raise
  rescue StandardError => err
    _log.log_backtrace(err)
    raise
  end
  private_class_method :seed_classes

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
    configure_logical_replication_handlers(monitor)

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
      LinuxAdmin::Service.new("evmserverd").restart
    end

    monitor.add_handler(rails_handler)
  end
  private_class_method :configure_rails_handler

  def self.configure_logical_replication_handlers(monitor)
    return unless MiqServer.my_server.has_active_role?("database_operations")

    local_db_conninfo = ActiveRecord::Base.connection.raw_connection.conninfo_hash.delete_blanks
    PglogicalSubscription.all.each do |s|
      handler = ManageIQ::PostgresHaAdmin::LogicalReplicationConfigHandler.new(:subscription => s.id, :conn_info => local_db_conninfo)
      _log.info("Configuring database failover for replication subscription #{s.id} ")

      handler.after_failover do |new_conn_info|
        s.delete
        PglogicalSubscription.new(new_conn_info.slice(:dbname, :host, :user, :password, :port)).save
      end

      monitor.add_handler(handler)
    end
  end
  private_class_method :configure_logical_replication_handlers
end
