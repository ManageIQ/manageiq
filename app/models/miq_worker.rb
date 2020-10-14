require 'io/wait'

class MiqWorker < ApplicationRecord
  include_concern 'ContainerCommon'
  include_concern 'SystemdCommon'
  include UuidMixin

  before_destroy :log_destroy_of_worker_messages

  belongs_to :miq_server
  has_many   :messages,           :as => :handler, :class_name => 'MiqQueue'
  has_many   :active_messages,    -> { where(["state = ?", "dequeue"]) }, :as => :handler, :class_name => 'MiqQueue'
  has_many   :ready_messages,     -> { where(["state = ?", "ready"]) }, :as => :handler, :class_name => 'MiqQueue'
  has_many   :processed_messages, -> { where(["state != ?", "ready"]) }, :as => :handler, :class_name => 'MiqQueue', :dependent => :destroy

  virtual_column :friendly_name, :type => :string
  virtual_column :uri_or_queue_name, :type => :string

  scope :with_miq_server_id, ->(server_id) { where(:miq_server_id => server_id) }
  scope :with_status,        ->(status)    { where(:status => status) }

  cattr_accessor :my_guid, :instance_accessor => false

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
  PROCESS_INFO_FIELDS = %i(priority memory_usage percent_memory percent_cpu memory_size cpu_time proportional_set_size unique_set_size)

  PROCESS_TITLE_PREFIX = "MIQ:".freeze

  def self.atShutdown
    stop_workers
  end

  class << self
    attr_writer :workers
  end

  def self.bundler_groups
    %w[manageiq_default ui_dependencies]
  end

  def self.kill_priority
    raise NotImplementedError, ".kill_priority must be implemented in a subclass"
  end

  def self.workers
    return 0 unless has_required_role?
    return @workers.call if @workers.kind_of?(Proc)
    return @workers unless @workers.nil?
    workers_configured_count
  end

  def self.scalable?
    maximum_workers_count.nil? || maximum_workers_count > 1
  end

  def scalable?
    self.class.scalable?
  end

  def self.workers_configured_count
    count = worker_settings[:count]
    if maximum_workers_count.kind_of?(Integer)
      count = maximum_workers_count if maximum_workers_count < count
    end
    count
  end

  class_attribute :default_queue_name, :required_roles, :maximum_workers_count, :include_stopping_workers_on_synchronize
  self.include_stopping_workers_on_synchronize = false
  self.required_roles = []

  def self.server_scope
    return current_scope if current_scope && current_scope.where_values_hash.include?('miq_server_id')
    where(:miq_server_id => MiqServer.my_server&.id)
  end

  CONDITION_CURRENT = {:status => STATUSES_CURRENT}
  def self.find_current
    server_scope.where(CONDITION_CURRENT)
  end

  def self.find_current_in_my_region
    in_my_region.where(CONDITION_CURRENT)
  end

  def self.find_starting
    server_scope.where(:status => STATUSES_STARTING)
  end

  def self.find_current_or_starting
    server_scope.where(:status => STATUSES_CURRENT_OR_STARTING)
  end

  def self.find_alive
    server_scope.where(:status => STATUSES_ALIVE)
  end

  def self.has_required_role?
    roles = if required_roles.kind_of?(Proc)
              required_roles.call
            else
              required_roles
            end

    return true if roles.blank?

    roles = Array(roles) if roles.kind_of?(String)
    raise _("Unexpected type: <self.required_roles.class.name>") unless roles.kind_of?(Array)

    roles.any? { |role| MiqServer.my_server.has_active_role?(role) }
  end

  def self.enough_resource_to_start_worker?
    MiqServer.my_server.enough_resource_to_start_worker?(self)
  end

  def self.sync_workers
    w       = include_stopping_workers_on_synchronize ? find_alive : find_current_or_starting
    current = w.length
    desired = workers
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
      server_config = options[:config] || miq_server.settings
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
            if settings[k].kind_of?(String)
              if settings[k].number_with_method?
                settings[k] = settings[k].to_i_with_method
              elsif settings[k] =~ /\A\d+(.\d+)?\z/ # case where int/float saved as string
                settings[k] = settings[k].to_i
              end
            end
          end
        end
      end
    end

    settings
  end

  def worker_settings(options = {})
    self.class.fetch_worker_settings_from_server(miq_server, options)
  end

  def heartbeat_file
    @heartbeat_file ||= Workers::MiqDefaults.heartbeat_file(guid)
  end

  def self.worker_settings(options = {})
    fetch_worker_settings_from_server(MiqServer.my_server, options)
  end

  def self.start_workers
    return unless self.has_required_role?
    workers.times { start_worker }
  end

  def self.stop_workers
    server_scope.each(&:stop)
  end

  def self.restart_workers
    find_current.each(&:restart)
  end

  def self.status_update
    find_current.each(&:status_update)
  end

  def self.log_status(level = :info)
    find_current.each { |w| w.log_status(level) }
  end

  def self.init_worker_object(*params)
    params                  = params.first
    params                  = {} unless params.kind_of?(Hash)
    params[:queue_name]     = default_queue_name unless params.key?(:queue_name) || default_queue_name.nil?
    params[:status]         = STATUS_CREATING
    params[:last_heartbeat] = Time.now.utc

    server_scope.new(params)
  end

  def self.create_worker_record(*params)
    init_worker_object(*params).tap(&:save!)
  end

  def self.start_worker(*params)
    w = containerized_worker? ? init_worker_object(*params) : create_worker_record(*params)
    w.start
    w
  end

  cache_with_timeout(:my_worker) { server_scope.find_by(:guid => my_guid) }

  def self.status_update_all
    MiqWorker.status_update
  end

  def self.log_status_all(level = :info)
    MiqWorker.log_status(level)
  end

  def self.containerized_worker?
    MiqEnvironment::Command.is_podified?
  end

  def containerized_worker?
    self.class.containerized_worker?
  end

  def self.systemd_worker?
    MiqEnvironment::Command.supports_systemd? && supports_systemd?
  end

  def systemd_worker?
    self.class.systemd_worker?
  end

  def start_runner
    if systemd_worker?
      start_systemd_worker
    elsif containerized_worker?
      start_runner_via_container
    else
      start_runner_via_spawn
    end
  end

  def start_runner_via_container
    create_container_objects
  end

  def self.build_command_line(guid, ems_id = nil)
    raise ArgumentError, "No guid provided" unless guid

    require 'awesome_spawn'
    cmd = "#{Gem.ruby} #{runner_script}"
    cmd = "nice -n #{nice_increment} #{cmd}" if ENV["APPLIANCE"]

    options = {:guid => guid, :heartbeat => nil}
    if ems_id
      options[:ems_id] = ems_id.kind_of?(Array) ? ems_id.join(",") : ems_id
    end
    "#{AwesomeSpawn::CommandLineBuilder.new.build(cmd, options)} #{name}"
  end

  def self.runner_script
    script = ManageIQ.root.join("lib/workers/bin/run_single_worker.rb")
    raise "script not found: #{script}" unless File.exist?(script)
    script
  end

  def command_line
    self.class.build_command_line(*worker_options.values_at(:guid, :ems_id))
  end

  def start_runner_via_spawn
    pid = Kernel.spawn(
      {"BUNDLER_GROUPS" => self.class.bundler_groups.join(",")},
      command_line,
      [:out, :err] => [Rails.root.join("log", "evm.log"), "a"]
    )
    Process.detach(pid)
    pid
  end

  def start
    self.pid = start_runner
    save if !containerized_worker? && !systemd_worker?

    msg = "Worker started: ID [#{id}], PID [#{pid}], GUID [#{guid}]"
    MiqEvent.raise_evm_event_queue(miq_server || MiqServer.my_server, "evm_worker_start", :event_details => msg, :type => self.class.name)

    _log.info(msg)
    self
  end

  def stop
    miq_server.stop_worker_queue(self)
  end

  # Let the worker monitor start a new worker
  alias_method :restart, :stop

  def kill
    kill_process
    destroy
  end

  # kill needs be done by the worker's orchestrator pod / server process
  # TODO: Note, stop is async through the queue, while kill is sync.  Should kill be async too?
  # Also, this looks a lot like MiqServer#stop_worker_queue except stop_worker is called on the server row whereas
  # we're calling kill on the worker row.
  def kill_async
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'kill',
      :queue_name  => 'miq_server',
      :server_guid => miq_server.guid,
      :zone        => miq_server.my_zone
    )
  end

  def kill_process
    if containerized_worker?
      delete_container_objects
      return
    end

    unless pid.nil?
      begin
        _log.info("Killing worker: ID [#{id}], PID [#{pid}], GUID [#{guid}], status [#{status}]")
        Process.kill(9, pid)
        loop do
          break unless is_alive?
          sleep(0.01)
        end
      rescue Errno::ESRCH
        _log.warn("Worker ID [#{id}] PID [#{pid}] GUID [#{guid}] has been killed")
      rescue => err
        _log.warn("Worker ID [#{id}] PID [#{pid}] GUID [#{guid}] has been killed, but with the following error: #{err}")
      end
    end
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

  def started?
    STATUS_STARTED == status
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
    stopping_timeout = self.class.worker_settings[:stopping_timeout] || Workers::MiqDefaults.stopping_timeout
    status == MiqWorker::STATUS_STOPPING && (last_heartbeat + current_timeout.to_i) < stopping_timeout.seconds.ago
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
      m.update(:handler_id => nil, :handler_type => nil) rescue nil
    end

    processed_messages.each do |m|
      _log.warn("Destroying: #{MiqQueue.format_full_log_msg(m)}") rescue nil
    end
  end

  def status_update
    return if MiqEnvironment::Command.is_podified?

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
      update!(pinfo)
    end
  end

  def log_status(level = :info)
    _log.send(level, "[#{friendly_name}] Worker ID [#{id}], PID [#{pid}], GUID [#{guid}], Last Heartbeat [#{last_heartbeat}], Process Info: Memory Usage [#{memory_usage}], Memory Size [#{memory_size}], Proportional Set Size: [#{proportional_set_size}], Unique Set Size: [#{unique_set_size}], Memory % [#{percent_memory}], CPU Time [#{cpu_time}], CPU % [#{percent_cpu}], Priority [#{os_priority}]")
  end

  def current_timeout
    msg = active_messages.first
    msg.try(:msg_timeout)
  end

  def uri_or_queue_name
    uri || queue_name
  end

  def friendly_name
    normalized_type.titleize
  end

  delegate :normalized_type, :to => :class

  def self.abbreviated_class_name
    name.sub(/^ManageIQ::Providers::/, "")
  end

  def abbreviated_class_name
    self.class.abbreviated_class_name
  end

  def self.minimal_class_name
    abbreviated_class_name
      .sub(/Miq/, "")
      .sub(/Worker/, "")
  end

  def minimal_class_name
    self.class.minimal_class_name
  end

  def database_application_name
    zone = MiqServer.my_server.zone
    "MIQ|#{Process.pid}|#{miq_server.compressed_id}|#{compressed_id}|#{zone.compressed_id}|#{minimal_class_name}|#{zone.name}".truncate(64)
  end

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

  def self.nice_increment
    delta = worker_settings[:nice_delta]
    delta.kind_of?(Integer) ? delta.to_s : "10"
  end

  def self.display_name(number = 1)
    n_('Worker', 'Workers', number)
  end

  private_class_method :nice_increment
end
