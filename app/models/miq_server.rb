require 'resolv'

class MiqServer < ApplicationRecord
  include_concern 'AtStartup'
  include_concern 'WorkerManagement'
  include_concern 'ServerMonitor'
  include_concern 'ServerSmartProxy'
  include_concern 'ConfigurationManagement'
  include_concern 'EnvironmentManagement'
  include_concern 'LogManagement'
  include_concern 'QueueManagement'
  include_concern 'RoleManagement'
  include_concern 'StatusManagement'
  include_concern 'UpdateManagement'

  include UuidMixin
  acts_as_miq_taggable
  include MiqPolicyMixin
  include RelationshipMixin

  alias_attribute :description, :name

  belongs_to              :vm, :inverse_of => :miq_server
  belongs_to              :zone
  has_many                :messages,  :as => :handler, :class_name => 'MiqQueue'
  has_many                :miq_events, :as => :target

  before_destroy          :validate_is_deleteable
  after_destroy           :destroy_linked_events_queue

  default_value_for(:name, "EVM")
  default_value_for(:zone) { Zone.default_zone }

  scope :active_miq_servers, -> { where(:status => STATUSES_ACTIVE) }
  scope :recently_active,    -> { where(:last_heartbeat => 10.minutes.ago.utc...Time.now.utc) }
  scope :with_zone_id, ->(zone_id) { where(:zone_id => zone_id) }
  virtual_delegate :description, :to => :zone, :prefix => true, :allow_nil => true, :type => :string

  validate :validate_zone_not_maintenance?
  validate :zone_unchanged_in_pods, :on => :update

  GUID_FILE = Rails.root.join("GUID").freeze

  STATUS_STARTING       = 'starting'.freeze
  STATUS_STARTED        = 'started'.freeze
  STATUS_RESTARTING     = 'restarting'.freeze
  STATUS_STOPPED        = 'stopped'.freeze
  STATUS_QUIESCE        = 'quiesce'.freeze
  STATUS_NOT_RESPONDING = 'not responding'.freeze
  STATUS_KILLED         = 'killed'.freeze

  STATUSES_STOPPED = [STATUS_STOPPED, STATUS_KILLED]
  STATUSES_ACTIVE  = [STATUS_STARTING, STATUS_STARTED]
  STATUSES_ALIVE   = STATUSES_ACTIVE + [STATUS_RESTARTING, STATUS_QUIESCE]

  RESTART_EXIT_STATUS = 123

  def validate_zone_not_maintenance?
    errors.add(:zone, N_('cannot be maintenance zone')) if zone == Zone.maintenance_zone
  end

  def hostname
    h = super
    h if h.to_s.hostname?
  end

  def starting_server_record
    self.started_on = self.last_heartbeat = Time.now.utc
    self.stopped_on = ""
    self.status     = "starting"
    self.pid        = Process.pid
    self.build      = Vmdb::Appliance.BUILD
    self.version    = Vmdb::Appliance.VERSION
    self.is_master  = false
    self.sql_spid   = ActiveRecord::Base.connection.spid
    save
  end

  def destroy_linked_events_queue
    MiqQueue.put(
      :class_name  => "MiqServer",
      :method_name => 'destroy_linked_events',
      :args        => [id],
      :zone        => my_zone
    )
  end

  def self.destroy_linked_events(server_id)
    EventStream.where(:target_id => server_id, :target_type => "MiqServer").destroy_all
  end

  def self.pidfile
    @pidfile ||= "#{Rails.root}/tmp/pids/evm.pid"
  end

  def self.running?
    p = PidFile.new(pidfile)
    p.running? ? p.pid : false
  end

  def self.seed
    unless exists?(:guid => my_guid)
      _log.info("Creating Default MiqServer with guid=[#{my_guid}], zone=[#{Zone.default_zone.name}]")
      create!(:guid => my_guid, :zone => Zone.default_zone)
      my_server_clear_cache
      ::Settings.reload! # Reload the Settings now that we have a server record
      _log.info("Creating Default MiqServer... Complete")
    end
    my_server
  end

  def validate_is_deleteable
    unless self.is_deleteable?
      _log.error(@errors.full_messages)
      throw :abort
    end
  end

  def heartbeat
    # Heartbeat the server
    t = Time.now.utc
    _log.info("Heartbeat [#{t}]...")
    reload
    self.last_heartbeat = t
    self.status = "started" if status == "not responding"
    save
    _log.info("Heartbeat [#{t}]...Complete")
  end

  def log_active_servers
    MiqRegion.my_region.active_miq_servers.sort_by { |s| [s.my_zone, s.name] }.each do |s|
      local  = s.is_local? ? 'Y' : 'N'
      master = s.is_master? ? 'Y' : 'N'
      $log.info("MiqServer: local=#{local}, master=#{master}, status=#{'%08s' % s.status}, id=#{'%05d' % s.id}, pid=#{'%05d' % s.pid}, guid=#{s.guid}, name=#{s.name}, zone=#{s.my_zone}, hostname=#{s.hostname}, ipaddress=#{s.ipaddress}, version=#{s.version}, build=#{s.build}, active roles=#{s.active_role_names.join(':')}")
    end
  end

  def stop_poll
    ::Settings.server.stop_poll.to_i_with_method
  end

  def heartbeat_frequency
    ::Settings.server.heartbeat_frequency.to_i_with_method
  end

  def server_dequeue_frequency
    ::Settings.server.server_dequeue_frequency.to_i_with_method
  end

  def server_monitor_frequency
    ::Settings.server.server_monitor_frequency.to_i_with_method
  end

  def server_log_frequency
    ::Settings.server.server_log_frequency.to_i_with_method
  end

  def worker_dequeue_frequency
    ::Settings.server.worker_dequeue_frequency.to_i_with_method
  end

  def worker_messaging_frequency
    ::Settings.server.worker_messaging_frequency.to_i_with_method
  end

  def worker_monitor_frequency
    ::Settings.server.worker_monitor_frequency.to_i_with_method
  end

  def memory_threshold
    ::Settings.server.memory_threshold.to_i_with_method
  end

  def threshold_exceeded?(name, now = Time.now.utc)
    @thresholds ||= Hash.new(1.day.ago.utc)
    exceeded = now > (@thresholds[name] + send(name))
    @thresholds[name] = now if exceeded
    exceeded
  end

  def monitor
    now = Time.now.utc
    Benchmark.realtime_block(:heartbeat)               { heartbeat }                        if threshold_exceeded?(:heartbeat_frequency, now)
    Benchmark.realtime_block(:server_dequeue)          { process_miq_queue }                if threshold_exceeded?(:server_dequeue_frequency, now)

    Benchmark.realtime_block(:server_monitor) do
      monitor_servers
      monitor_server_roles if self.is_master?
    end if threshold_exceeded?(:server_monitor_frequency, now)

    Benchmark.realtime_block(:log_active_servers)      { log_active_servers }               if threshold_exceeded?(:server_log_frequency, now)
    Benchmark.realtime_block(:worker_monitor)          { monitor_workers }                  if threshold_exceeded?(:worker_monitor_frequency, now)
    Benchmark.realtime_block(:worker_dequeue)          { populate_queue_messages }          if threshold_exceeded?(:worker_dequeue_frequency, now)
    monitor_myself
  rescue SystemExit, SignalException
    # TODO: We're rescuing Exception below. WHY? :bomb:
    # A SystemExit would be caught below, so we need to explicitly rescue/raise.
    raise
  rescue Exception => err
    _log.error(err.message)
    _log.log_backtrace(err)

    begin
      _log.info("Reconnecting to database after error...")
      # Remove the connection and establish a new one since reconnect! doesn't always play nice with SSL postgresql connections
      spec_name = ActiveRecord::Base.connection_specification_name
      ActiveRecord::Base.establish_connection(ActiveRecord::Base.remove_connection(spec_name))
    rescue Exception => err
      _log.error("#{err.message}, during reconnect!")
    else
      _log.info("Reconnecting to database after error...Successful")
    end
  end

  def monitor_myself
    if memory_usage.to_i > memory_threshold
      msg = "server(pid: #{pid}, name: #{name}) memory usage [#{memory_usage.to_i}] exceeded limit: [#{memory_threshold}].  Exiting server process."
      _log.warn(msg)

      notification_options = {
        :name             => name,
        :memory_usage     => memory_usage.to_i,
        :memory_threshold => memory_threshold,
        :pid              => pid
      }
      Notification.create(:type => "evm_server_memory_exceeded", :options => notification_options)
      shutdown_and_exit(1)
    end
  end

  def stop(sync = false)
    return if self.stopped?

    shutdown_and_exit_queue
    wait_for_stopped if sync
  end

  def wait_for_stopped
    loop do
      reload
      break if self.stopped?
      sleep stop_poll
    end
  end

  def self.stop(sync = false)
    svr = my_server(true) rescue nil
    svr.stop(sync) unless svr.nil?
    PidFile.new(pidfile).remove
  end

  def kill
    # Kill all the workers of this server
    kill_all_workers

    # Then kill this server
    _log.info("initiated for #{format_full_log_msg}")
    update(:stopped_on => Time.now.utc, :status => "killed", :is_master => false)
    (pid == Process.pid) ? shutdown_and_exit : Process.kill(9, pid)
  end

  def self.kill
    svr = my_server(true)
    svr.kill unless svr.nil?
    PidFile.new(pidfile).remove
  end

  def shutdown
    _log.info("initiated for #{format_full_log_msg}")
    MiqEvent.raise_evm_event(self, "evm_server_stop")

    quiesce
  end

  def shutdown_and_exit(exit_status = 0)
    shutdown
    exit exit_status
  end

  def quiesce
    update_attribute(:status, 'quiesce')
    deactivate_all_roles
    quiesce_all_workers
    update(:stopped_on => Time.now.utc, :status => "stopped", :is_master => false)
  end

  # Restart the local server
  def restart
    raise _("Server restart is only supported on Linux") unless MiqEnvironment::Command.is_linux?

    _log.info("Server restart initiating...")
    update_attribute(:status, "restarting")

    shutdown_and_exit(RESTART_EXIT_STATUS)
  end

  def format_full_log_msg
    "MiqServer [#{name}] with ID: [#{id}], PID: [#{pid}], GUID: [#{guid}]"
  end

  def format_short_log_msg
    "MiqServer [#{name}] with ID: [#{id}]"
  end

  def friendly_name
    _("EVM Server (%{id})") % {:id => pid}
  end

  def who_am_i
    @who_am_i ||= "#{name} #{my_zone} #{self.class.name} #{id}"
  end

  def database_application_name
    "MIQ|#{Process.pid}|#{compressed_id}|-|#{zone.compressed_id}|Server|#{zone.name}".truncate(64)
  end

  def set_database_application_name
    ArApplicationName.name = database_application_name
  end

  def is_local?
    guid == MiqServer.my_guid
  end

  def is_remote?
    !is_local?
  end

  def is_recently_active?
    last_heartbeat && (last_heartbeat >= 10.minutes.ago.utc)
  end

  def is_deleteable?
    return true if MiqEnvironment::Command.is_podified?

    if self.is_local?
      message = N_("Cannot delete currently used %{log_message}") % {:log_message => format_short_log_msg}
      @errors ||= ActiveModel::Errors.new(self)
      @errors.add(:base, message)
      return false
    end
    return true if self.stopped?

    if is_recently_active?
      message = N_("Cannot delete recently active %{log_message}") % {:log_message => format_short_log_msg}
      @errors ||= ActiveModel::Errors.new(self)
      @errors.add(:base, message)
      return false
    end

    true
  end

  def started?
    status == "started"
  end

  def stopped?
    STATUSES_STOPPED.include?(status)
  end

  def active?
    STATUSES_ACTIVE.include?(status)
  end

  def alive?
    STATUSES_ALIVE.include?(status)
  end

  def logon_status
    return :ready if self.started?
    started_on < (Time.now.utc - ::Settings.server.startup_timeout) ? :timed_out_starting : status.to_sym
  end

  def logon_status_details
    result = {:status => logon_status}
    return result if result[:status] == :ready

    wcnt = MiqWorker.find_starting.length
    workers = wcnt == 1 ? "worker" : "workers"
    message = "Waiting for #{wcnt} #{workers} to start"
    result.merge(:message => message)
  end

  #
  # Zone and Role methods
  #
  @@my_guid_mutex = Mutex.new
  def self.my_guid
    @@my_guid_mutex.synchronize { @@my_guid ||= load_or_generate_guid }
  end

  # Under normal circumstances there really shouldn't be any reason to use
  # this method. It should only be used for tests and when we need to monitor
  # multiple servers.
  def self.my_guid=(guid)
    @@my_guid_mutex.synchronize { @@my_guid = guid }
  end

  def self.load_or_generate_guid
    guid = File.read(GUID_FILE).strip if File.exist?(GUID_FILE)
    return guid if guid.present?

    SecureRandom.uuid.tap do |guid|
      _log.info("Generated MiqServer GUID #{guid}")
      File.open(GUID_FILE, "wb") do |file|
        file.sync = true
        file.write(guid)
      end
    end
  end

  cache_with_timeout(:my_server) { find_by(:guid => my_guid) }

  def self.my_zone(force_reload = false)
    my_server(force_reload).my_zone
  end

  def self.my_roles(force_reload = false)
    my_server(force_reload).my_roles
  end

  def self.my_role(force_reload = false)
    my_server(force_reload).my_role
  end

  def self.my_active_roles(force_reload = false)
    my_server(force_reload).active_role_names
  end

  def self.my_active_role(force_reload = false)
    my_server(force_reload).active_role
  end

  def self.licensed_roles(force_reload = false)
    my_server(force_reload).licensed_roles
  end

  def my_zone
    zone.name
  end

  def has_zone?(zone_name)
    my_zone == zone_name
  end

  def find_other_started_servers_in_region
    self.class.active_miq_servers.in_my_region.where.not(:id => id).to_a
  end

  def find_other_servers_in_region
    self.class.active_miq_servers.where.not(:id => id).to_a
  end

  def find_other_started_servers_in_zone
    self.class.active_miq_servers.where(:zone_id => zone_id).where.not(:id => id).to_a
  end

  def find_other_servers_in_zone
    self.class.where(:zone_id => zone_id).where.not(:id => id).to_a
  end

  def display_name
    "#{name} [#{id}]"
  end

  def server_timezone
    ::Settings.server.timezone || "UTC"
  end

  def tenant_identity
    User.super_admin
  end

  def miq_region
    MiqRegion.find_by(:region => region_id)
  end

  def self.display_name(number = 1)
    n_('Server', 'Servers', number)
  end

  def self.zone_is_modifiable?
    return false if MiqEnvironment::Command.is_podified?

    Zone.visible.in_my_region.count > 1
  end

  def self.managed_resources
    {
      :vms                     => Vm.active.count,
      :hosts                   => Host.active.count,
      :aggregate_physical_cpus => Host.active.in_my_region.sum(:aggregate_physical_cpus),
    }
  end

  def self.unmanaged_resources
    {
      :vms                     => Vm.not_active.count,
      :hosts                   => Host.archived.count,
      :aggregate_physical_cpus => Host.archived.in_my_region.sum(:aggregate_physical_cpus),
    }
  end

  def self.audit_managed_resources
    totals = managed_resources.slice(:vms, :hosts)
    $audit_log.info("Under Management: #{totals.to_json}")
  end

  private

  def zone_unchanged_in_pods
    return unless MiqEnvironment::Command.is_podified?

    errors.add(:zone, N_('cannot be changed when running in containers')) if zone_id_changed?
  end
end # class MiqServer
