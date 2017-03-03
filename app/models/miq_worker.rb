require 'io/wait'

class MiqWorker < ApplicationRecord
  include UuidMixin

  before_destroy :log_destroy_of_worker_messages

  belongs_to :miq_server
  has_many   :messages,           :as => :handler, :class_name => 'MiqQueue'
  has_many   :active_messages,    -> { where ["state = ?", "dequeue"] }, :as => :handler, :class_name => 'MiqQueue'
  has_many   :ready_messages,     -> { where ["state = ?", "ready"] }, :as => :handler, :class_name => 'MiqQueue'
  has_many   :processed_messages, -> { where ["state != ?", "ready"] }, :as => :handler, :class_name => 'MiqQueue', :dependent => :destroy

  virtual_column :friendly_name, :type => :string
  virtual_column :uri_or_queue_name, :type => :string

  STATUS_CREATING = 'creating'.freeze
  STATUS_STARTING = 'starting'.freeze
  STATUS_STARTED  = 'started'.freeze
  STATUS_READY    = 'ready'.freeze
  STATUS_WORKING  = 'working'.freeze
  STATUS_STOPPING = 'stopping'.freeze
  STATUS_STOPPED  = 'stopped'.freeze
  STATUS_KILLED   = 'killed'.freeze
  STATUS_ABORTED  = 'aborted'.freeze

  STATUSES_STARTING = [STATUS_CREATING, STATUS_STARTING]
  STATUSES_CURRENT  = [STATUS_STARTED, STATUS_READY, STATUS_WORKING]
  STATUSES_STOPPED  = [STATUS_STOPPED, STATUS_KILLED, STATUS_ABORTED]
  STATUSES_CURRENT_OR_STARTING = STATUSES_CURRENT + STATUSES_STARTING
  STATUSES_ALIVE    = STATUSES_CURRENT_OR_STARTING + [STATUS_STOPPING]
  PROCESS_INFO_FIELDS = %i(priority memory_usage percent_memory percent_cpu memory_size cpu_time proportional_set_size)

  PROCESS_TITLE_PREFIX = "MIQ:".freeze
  def self.atStartup
    # Delete and Kill all workers that were running previously
    clean_all_workers
  end

  def self.atShutdown
    stop_all_workers
  end

  class << self
    attr_writer :workers
  end

  def self.workers
    return (self.has_minimal_env_option? ? 1 : 0) if MiqServer.minimal_env? && check_for_minimal_role
    return @workers.call if @workers.kind_of?(Proc)
    return @workers unless @workers.nil?
    workers_configured_count
  end

  def self.workers_configured_count
    count = worker_settings[:count]
    if maximum_workers_count.kind_of?(Integer)
      count = maximum_workers_count if maximum_workers_count < count
    end
    count
  end

  def self.has_minimal_env_option?
    return false if MiqServer.minimal_env_options.empty? || required_roles.blank?

    case required_roles
    when String
      MiqServer.minimal_env_options.include?(required_roles)
    when Array
      required_roles.any? { |role| MiqServer.minimal_env_options.include?(role) }
    else
      raise _("Unexpected type: <self.required_roles.class.name>")
    end
  end

  class_attribute :check_for_minimal_role, :default_queue_name, :required_roles, :maximum_workers_count, :include_stopping_workers_on_synchronize
  self.include_stopping_workers_on_synchronize = false
  self.check_for_minimal_role = true
  self.required_roles         = []

  def self.server_scope(server_id = nil)
    return current_scope if current_scope && current_scope.where_values_hash.include?('miq_server_id')
    if server_id.nil?
      server = MiqServer.my_server
      server_id = server.id unless server.nil?
    end
    where(:miq_server_id => server_id)
  end

  CONDITION_CURRENT = {:status => STATUSES_CURRENT}
  def self.find_current(server_id = nil)
    server_scope(server_id).where(CONDITION_CURRENT)
  end

  def self.find_current_in_region(region)
    in_region(region).where(CONDITION_CURRENT)
  end

  def self.find_current_in_my_region
    in_my_region.where(CONDITION_CURRENT)
  end

  def self.find_current_in_zone(zone_id)
    where(CONDITION_CURRENT.merge(:miq_server_id => Zone.find(zone_id).miq_servers)).to_a
  end

  def self.find_current_in_my_zone
    where(CONDITION_CURRENT.merge(:miq_server_id => MiqServer.my_server.zone.miq_servers)).to_a
  end

  def self.find_starting(server_id = nil)
    server_scope(server_id).where(:status => STATUSES_STARTING)
  end

  def self.find_current_or_starting(server_id = nil)
    server_scope(server_id).where(:status => STATUSES_CURRENT_OR_STARTING)
  end

  def self.find_alive(server_id = nil)
    server_scope(server_id).where(:status => STATUSES_ALIVE)
  end

  def self.has_required_role?
    return true if required_roles.blank?

    case required_roles
    when String
      MiqServer.my_server.has_active_role?(required_roles)
    when Array
      required_roles.any? { |role| MiqServer.my_server.has_active_role?(role) }
    else
      raise _("Unexpected type: <self.required_roles.class.name>")
    end
  end

  def self.enough_resource_to_start_worker?
    MiqServer.my_server.enough_resource_to_start_worker?(self)
  end

  def self.sync_workers
    w       = include_stopping_workers_on_synchronize ? find_alive : find_current_or_starting
    current = w.length
    desired = self.has_required_role? ? workers : 0
    result  = {:adds => [], :deletes => []}

    if current != desired
      _log.info("Workers are being synchronized: Current #: [#{current}], Desired #: [#{desired}]")

      if desired > current && enough_resource_to_start_worker?
        (desired - current).times { result[:adds] << start_worker.pid }
      elsif desired < current
        w = w.to_a
        (current - desired).times do
          ww = w.pop
          result[:deletes] << ww.pid
          ww.stop
        end
      end
    end

    result
  end

  # Convert the Models name from MiqGenericWorker to :generic_worker
  def self.settings_name
    @settings_name ||=
      if self == MiqWorker
        :worker_base
      elsif parent.try(:short_token)
        # :generic_worker_infra, :generic_worker_vmware
        :"#{normalized_type}_#{parent.short_token.underscore}"
      else
        # :generic_worker
        normalized_type.to_sym
      end
  end

  # Grab all the classes in the hierarchy below ActiveRecord::Base
  def self.path_to_my_worker_settings
    @path_to_my_worker_settings ||=
      ancestors.grep(Class).select { |c| c <= MiqWorker }.reverse.collect(&:settings_name)
  end

  def self.fetch_worker_settings_from_server(miq_server, options = {})
    settings = {}

    unless miq_server.nil?
      server_config = options[:config] || miq_server.get_config("vmdb")
      server_config = server_config.config if server_config.respond_to?(:config)
      # Get the configuration values
      section = server_config[:workers]
      unless section.nil?
        classes = path_to_my_worker_settings
        classes.each do |c|
          section = section[c]
          raise _("Missing config section %{section_name}") % {:section_name => c} if section.nil?
          defaults = section[:defaults]
          settings.merge!(defaults) unless defaults.nil?
        end

        settings.merge!(section)

        # If not specified, provide the worker_settings cleaned up in fixnums, etc. instead of 1.seconds, 10.megabytes
        raw = options[:raw] == true

        # Clean up the configuration values in a format like "30.seconds"
        unless raw
          settings.keys.each do |k|
            settings[k] = settings[k].to_i_with_method if settings[k].respond_to?(:to_i_with_method) && settings[k].number_with_method?
          end
        end
      end
    end

    settings
  end

  def worker_settings(options = {})
    self.class.fetch_worker_settings_from_server(miq_server, options)
  end

  def self.worker_settings(options = {})
    fetch_worker_settings_from_server(MiqServer.my_server, options)
  end

  def self.start_workers
    return unless self.has_required_role?
    workers.times { start_worker }
  end

  def self.stop_workers(server_id = nil)
    server_scope(server_id).each(&:stop)
  end

  def self.restart_workers(server_id = nil)
    find_current(server_id).each(&:restart)
  end

  def self.clean_workers
    time_threshold = 1.hour
    server_scope.each do |w|
      Process.kill(9, w.pid) if w.pid && w.is_alive? rescue nil
      # if w.last_heartbeat && (time_threshold.ago.utc < w.last_heartbeat)
      #   ActiveRecord::Base.connection.kill(w.sql_spid)
      # end
      w.destroy
    end
  end

  def self.status_update
    find_current.each(&:status_update)
  end

  def self.log_status(level = :info)
    find_current.each { |w| w.log_status(level) }
  end

  def self.create_worker_record(*params)
    params                  = params.first
    params                  = {} unless params.kind_of?(Hash)
    params[:queue_name]     = default_queue_name unless params.key?(:queue_name) || default_queue_name.nil?
    params[:status]         = STATUS_CREATING
    params[:last_heartbeat] = Time.now.utc

    server_scope.create(params)
  end

  def self.start_worker(*params)
    w = create_worker_record(*params)
    w.start
    w
  end

  def self.find_all_current(server_id = nil)
    MiqWorker.find_current(server_id)
  end

  def self.stop_all_workers(server_id = nil)
    MiqWorker.stop_workers(server_id)
  end

  def self.restart_all_workers(server_id = nil)
    MiqWorker.restart_workers(server_id)
  end

  def self.clean_all_workers
    MiqWorker.clean_workers
  end

  def self.status_update_all
    MiqWorker.status_update
  end

  def self.log_status_all(level = :info)
    MiqWorker.log_status(level)
  end

  def self.send_message_to_worker_monitor(wid, message, *args)
    w = MiqWorker.find_by_id(wid)
    raise _("Worker with id=<%{id}> does not exist") % {:id => wid} if w.nil?
    w.send_message_to_worker_monitor(message, *args)
  end

  def send_message_to_worker_monitor(message, *args)
    MiqQueue.put(
      :class_name  => 'MiqServer',
      :instance_id => miq_server.id,
      :method_name => 'message_for_worker',
      :args        => [id, message, *args],
      :queue_name  => 'miq_server',
      :zone        => miq_server.zone.name,
      :server_guid => miq_server.guid
    )
  end

  def self.before_fork
    preload_for_worker_role if respond_to?(:preload_for_worker_role)
  end

  def self.after_fork
    close_pg_sockets_inherited_from_parent
    DRb.stop_service
    renice(Process.pid)
  end

  # When we fork, the children inherits the parent's file descriptors
  # so we need to close any inherited raw pg sockets in the child.
  def self.close_pg_sockets_inherited_from_parent
    owner_to_pool = ActiveRecord::Base.connection_handler.instance_variable_get(:@owner_to_pool)
    owner_to_pool[Process.ppid].values.compact.each do |pool|
      pool.connections.each do |conn|
        socket = conn.raw_connection.socket
        _log.info "Closing socket: #{socket}"
        IO.for_fd(socket).close
      end
    end
  end

  def start
    self.class.before_fork
    pid = fork(:cow_friendly => true) do
      self.class.after_fork
      self.class::Runner.start_worker(worker_options)
      exit!
    end

    Process.detach(pid)
    self.pid = pid
    save

    msg = "Worker started: ID [#{id}], PID [#{pid}], GUID [#{guid}]"
    MiqEvent.raise_evm_event_queue(miq_server, "evm_worker_start", :event_details => msg, :type => self.class.name)

    _log.info(msg)
    self
  end

  def stop
    miq_server.stop_worker_queue(self)
  end

  # Let the worker monitor start a new worker
  alias_method :restart, :stop

  def kill
    unless pid.nil?
      begin
        _log.info("Killing worker: ID [#{id}], PID [#{pid}], GUID [#{guid}], status [#{status}]")
        Process.kill(9, pid)
      rescue Errno::ESRCH
        _log.warn("Worker ID [#{id}] PID [#{pid}] GUID [#{guid}] has been killed")
      rescue => err
        _log.warn("Worker ID [#{id}] PID [#{pid}] GUID [#{guid}] has been killed, but with the following error: #{err}")
      end
    end

    # ActiveRecord::Base.connection.kill(self.sql_spid)
    destroy
  end

  def quiesce_time_allowance
    allowance = self.class.worker_settings[:quiesce_time_allowance]
    @quiesce_time_allowance ||= allowance || current_timeout || 5.minutes
  end

  def is_current?
    STATUSES_CURRENT.include?(status)
  end

  def is_alive?
    STATUSES_ALIVE.include?(status) && actually_running?
  end

  def is_stopped?
    STATUSES_STOPPED.include?(status)
  end

  def actually_running?
    MiqProcess.is_worker?(pid)
  end

  def enabled_or_running?
    !is_stopped? || actually_running?
  end

  def stopping_for_too_long?
    # Note, a 'stopping' worker heartbeats in DRb but NOT to
    # the database, so we can see how long it's been
    # 'stopping' by checking the last_heartbeat.
    stopping_timeout = self.class.worker_settings[:stopping_timeout] || 10.minutes
    status == MiqWorker::STATUS_STOPPING && last_heartbeat < stopping_timeout.seconds.ago
  end

  def validate_active_messages
    active_messages.each { |msg| msg.check_for_timeout(_log.prefix) }
  end

  def clean_active_messages
    active_messages.each do |m|
      _log.warn("Message id: [#{m.id}] Setting state to 'error'")
      m.delivered_in_error('Clean Active Messages')
    end
  end

  def log_destroy_of_worker_messages
    ready_messages.each do |m|
      _log.warn("Nullifying: #{MiqQueue.format_full_log_msg(m)}") rescue nil
      m.update_attributes(:handler_id => nil, :handler_type => nil) rescue nil
    end

    processed_messages.each do |m|
      _log.warn("Destroying: #{MiqQueue.format_full_log_msg(m)}") rescue nil
    end
  end

  def status_update
    begin
      pinfo = MiqProcess.processInfo(pid)
    rescue Errno::ESRCH
      update(:status => STATUS_ABORTED)
      _log.warn("No such process [#{friendly_name}] with PID=[#{pid}], aborting worker.")
    rescue => err
      _log.warn("Unexpected error: #{err.message}, while requesting process info for [#{friendly_name}] with PID=[#{pid}]")
    else
      # Ensure the hash only contains the values we want to store in the table
      pinfo.slice!(*PROCESS_INFO_FIELDS)
      pinfo[:os_priority] = pinfo.delete(:priority)
      update_attributes!(pinfo)
    end
  end

  def log_status(level = :info)
    _log.send(level, "[#{friendly_name}] Worker ID [#{id}], PID [#{pid}], GUID [#{guid}], Last Heartbeat [#{last_heartbeat}], Process Info: Memory Usage [#{memory_usage}], Memory Size [#{memory_size}], Proportional Set Size: [#{proportional_set_size}], Memory % [#{percent_memory}], CPU Time [#{cpu_time}], CPU % [#{percent_cpu}], Priority [#{os_priority}]")
  end

  def current_timeout
    msg = active_messages.first
    msg.nil? ? nil : msg.msg_timeout
  end

  def uri_or_queue_name
    uri || queue_name
  end

  def friendly_name
    normalized_type.titleize
  end

  delegate :normalized_type, :to => :class

  def format_full_log_msg
    "Worker [#{self.class}] with ID: [#{id}], PID: [#{pid}], GUID: [#{guid}]"
  end

  def format_short_log_msg
    "Worker ID: [#{id}]"
  end

  def self.release_db_connection
    ActiveRecord::Base.connection_pool.release_connection if ActiveRecord::Base.connected?
  end

  def update_heartbeat
    update_attribute(:last_heartbeat, Time.now.utc)
  end

  def is_current_process?
    Process.pid == pid
  end

  def self.config_settings_path
    @config_settings_path ||= [:workers] + path_to_my_worker_settings
  end

  class << self
    attr_writer :config_settings_path
  end

  def update_spid(spid = ActiveRecord::Base.connection.spid)
    self.sql_spid = spid
  end

  def update_spid!(spid = ActiveRecord::Base.connection.spid)
    if sql_spid != spid
      self.sql_spid = spid
      save
    end
  end

  def worker_options
    {:guid => guid}
  end

  def self.normalized_type
    @normalized_type ||= if parent == Object
                           name.sub(/^Miq/, '').underscore
                         else
                           name.demodulize.underscore
                         end
  end

  def self.renice(pid)
    AwesomeSpawn.run("renice", :params =>  {:n => nice_increment, :p => pid })
  end

  def self.nice_increment
    delta = worker_settings[:nice_delta]
    delta.kind_of?(Integer) ? delta.to_s : "+10"
  end
  private_class_method :nice_increment
end
