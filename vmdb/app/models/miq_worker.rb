require 'io/wait'

class MiqWorker < ActiveRecord::Base
  include UuidMixin
  include ReportableMixin

  before_validation :set_command_line, :on => :create

  before_destroy :log_destroy_of_worker_messages

  belongs_to :miq_server
  has_many   :messages,           :as => :handler, :class_name => 'MiqQueue'
  has_many   :active_messages,    :as => :handler, :class_name => 'MiqQueue', :conditions => [ "state = ?", "dequeue"]
  has_many   :ready_messages,     :as => :handler, :class_name => 'MiqQueue', :conditions => [ "state = ?", "ready"]
  has_many   :processed_messages, :as => :handler, :class_name => 'MiqQueue', :conditions => [ "state != ?", "ready"], :dependent => :destroy

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

  def self.atStartup
    # Delete and Kill all workers that were running previously
    self.clean_all_workers

    # Clean queue of any worker startup entries
    MiqQueue.destroy_all(:method_name => "start_event_monitor", :server_guid => MiqServer.my_guid)
  end

  def self.atShutdown
    self.stop_all_workers
  end

  def self.workers=(val)
    @workers = val
  end

  def self.workers
    return (self.has_minimal_env_option? ? 1 : 0) if MiqServer.minimal_env? && self.check_for_minimal_role
    return @workers.call if @workers.kind_of?(Proc)
    return @workers unless @workers.nil?
    return self.workers_configured_count
  end

  def self.workers_configured_count
    count = self.worker_settings[:count]
    if self.maximum_workers_count.kind_of?(Integer)
      count = self.maximum_workers_count if self.maximum_workers_count < count
    end
    count
  end

  def self.has_minimal_env_option?
    return false if MiqServer.minimal_env_options.empty? || self.required_roles.blank?

    case self.required_roles
    when String
      MiqServer.minimal_env_options.include?(self.required_roles)
    when Array
      self.required_roles.any? { |role| MiqServer.minimal_env_options.include?(role) }
    else
      raise "Unexpected type: <self.required_roles.class.name>"
    end
  end

  class_attribute :check_for_minimal_role, :default_queue_name, :required_roles, :maximum_workers_count, :include_stopping_workers_on_synchronize
  self.include_stopping_workers_on_synchronize = false
  self.check_for_minimal_role = true
  self.required_roles         = []

  def self.server_scope(server_id = nil)
    return current_scope if current_scope && current_scope.where_values_hash.include?(:miq_server_id)
    if server_id.nil?
      server = MiqServer.my_server
      server_id = server.id unless server.nil?
    end
    where(:miq_server_id => server_id)
  end

  CONDITION_CURRENT = {:status => STATUSES_CURRENT}
  def self.find_current(server_id = nil)
    self.server_scope(server_id).where(CONDITION_CURRENT)
  end

  def self.find_current_in_region(region)
    self.in_region(region).where(CONDITION_CURRENT)
  end

  def self.find_current_in_my_region
    self.in_my_region.where(CONDITION_CURRENT)
  end

  def self.find_current_in_zone(zone_id)
    self.where(CONDITION_CURRENT.merge(:miq_server_id => Zone.find(zone_id).miq_servers)).to_a
  end

  def self.find_current_in_my_zone
    self.where(CONDITION_CURRENT.merge(:miq_server_id => MiqServer.my_server.zone.miq_servers)).to_a
  end

  def self.find_starting(server_id = nil)
    self.server_scope(server_id).where(:status => STATUSES_STARTING)
  end

  def self.find_current_or_starting(server_id = nil)
    self.server_scope(server_id).where(:status => STATUSES_CURRENT_OR_STARTING)
  end

  def self.find_alive(server_id = nil)
    self.server_scope(server_id).where(:status => STATUSES_ALIVE)
  end

  def self.has_required_role?
    return true if self.required_roles.blank?

    case self.required_roles
    when String
      MiqServer.my_server.has_active_role?(self.required_roles)
    when Array
      self.required_roles.any? { |role| MiqServer.my_server.has_active_role?(role) }
    else
      raise "Unexpected type: <self.required_roles.class.name>"
    end
  end

  def self.enough_resource_to_start_worker?
    MiqServer.my_server.enough_resource_to_start_worker?(self)
  end

  def self.sync_workers
    w       = self.include_stopping_workers_on_synchronize ? self.find_alive : self.find_current_or_starting
    current = w.length
    desired = self.has_required_role? ? self.workers : 0
    result  = { :adds => [], :deletes => [] }

    if current != desired
      $log.info("MIQ(#{self.name}.sync_workers) Workers are being synchronized: Current #: [#{current}], Desired #: [#{desired}]")

      if desired > current && enough_resource_to_start_worker?
        (desired - current).times { result[:adds] << self.start_worker.pid }
      elsif desired < current
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
  def self.corresponding_helper
    @corresponding_helper ||= self == MiqWorker ? :worker_base  : self.name.underscore[4..-1].to_sym
  end

  # Grab all the classes in the hierarchy but ActiveRecord::Base and Object (and BasicObject on 1.9)
  def self.path_to_my_worker_settings
    excluded = %w(ActiveRecord::Base Object BasicObject)
    @path_to_my_worker_settings ||= self.hierarchy.reject {|c| excluded.include?(c.name)}.reverse.collect(&:corresponding_helper)
  end

  def self.fetch_worker_settings_from_server(miq_server, options = {})
    settings = {}

    unless miq_server.nil?
      server_config = options[:config] || miq_server.get_config("vmdb")
      server_config = server_config.config if server_config.respond_to?(:config)
      # Get the configuration values
      section = server_config[:workers]
      unless section.nil?
        classes = self.path_to_my_worker_settings
        classes.each do |c|
          section = section[c]
          raise "Missing config section #{c}" if section.nil?
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
    self.class.fetch_worker_settings_from_server(self.miq_server, options)
  end

  def self.worker_settings(options = {})
    self.fetch_worker_settings_from_server(MiqServer.my_server, options)
  end

  def self.start_workers
    return unless self.has_required_role?
    self.workers.times { self.start_worker }
  end

  def self.stop_workers(server_id = nil)
    self.server_scope(server_id).each(&:stop)
  end

  def self.restart_workers(server_id = nil)
    self.find_current(server_id).each(&:restart)
  end

  def self.clean_workers
    time_threshold = 1.hour
    self.server_scope.each do |w|
      Process.kill(9, w.pid) if w.pid && w.is_alive? rescue nil
      # if w.last_heartbeat && (time_threshold.ago.utc < w.last_heartbeat)
      #   ActiveRecord::Base.connection.kill(w.sql_spid)
      # end
      w.destroy
    end
  end

  def self.status_update
    self.find_current.each(&:status_update)
  end

  def self.log_status(level = :info)
    self.find_current.each { |w| w.log_status(level) }
  end

  def self.create_worker_record(*params)
    params                  = params.first
    params                  = {} unless params.kind_of?(Hash)
    params[:queue_name]     = self.default_queue_name unless params.has_key?(:queue_name) || self.default_queue_name.nil?
    params[:status]         = STATUS_CREATING
    params[:last_heartbeat] = Time.now.utc

    self.server_scope.create(params)
  end

  def self.start_worker(*params)
    w = self.create_worker_record(*params)
    w.start
    return w
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
    raise "Worker with id=<#{wid}> does not exist" if w.nil?
    w.send_message_to_worker_monitor(message, *args)
  end

  def send_message_to_worker_monitor(message, *args)
    MiqQueue.put(
      :class_name  => 'MiqServer',
      :instance_id => self.miq_server.id,
      :method_name => 'message_for_worker',
      :args        => [self.id, message, *args],
      :queue_name  => 'miq_server',
      :zone        => self.miq_server.zone.name,
      :server_guid => self.miq_server.guid
    )
  end

  def start
    msg = "Worker started: ID [#{self.id}], PID [#{self.pid}], GUID [#{self.guid}]"
    MiqEvent.raise_evm_event_queue(self.miq_server, "evm_worker_start", :event_details => msg, :type => self.class.name)

    ENV['MIQ_GUID'] = self.guid
    self.pid = Kernel.spawn(self.command_line, :out => "/dev/null", :err => [ Rails.root.join("log", "evm.log"), "a" ])
    Process.detach(pid)
    self.save

    $log.info("MIQ(#{self.class.name}.start) #{msg}")
  end

  def stop
    self.miq_server.stop_worker_queue(self)
  end

  # Let the worker monitor start a new worker
  alias restart stop

  def kill
    unless self.pid.nil?
      begin
        $log.info("MIQ(#{self.class.name}.kill) Killing worker: ID [#{self.id}], PID [#{self.pid}], GUID [#{self.guid}], status [#{self.status}]")
        Process.kill(9, self.pid)
      rescue Errno::ESRCH
        $log.warn("MIQ(#{self.class.name}.kill) Worker ID [#{self.id}] PID [#{self.pid}] GUID [#{self.guid}] has been killed")
      rescue => err
        $log.warn("MIQ(#{self.class.name}.kill) Worker ID [#{self.id}] PID [#{self.pid}] GUID [#{self.guid}] has been killed, but with the following error: #{err}")
      end
    end

    # ActiveRecord::Base.connection.kill(self.sql_spid)
    self.destroy
  end

  def quiesce_time_allowance
    allowance = self.class.worker_settings[:quiesce_time_allowance]
    @quiesce_time_allowance ||= allowance || self.current_timeout || 5.minutes
  end

  def is_current?
    STATUSES_CURRENT.include?(self.status)
  end

  def is_alive?
    STATUSES_ALIVE.include?(self.status) && MiqProcess.is_worker?(self.pid)
  end

  def is_stopped?
    STATUSES_STOPPED.include?(self.status)
  end

  def validate_active_messages
    log_prefix = "MIQ(#{self.class.name}.validate_active_messages)"
    self.active_messages.each { |msg| msg.check_for_timeout(log_prefix) }
  end

  def clean_active_messages
    self.active_messages.each do |m|
      $log.warn("MIQ(#{self.class.name}.clean_active_messages) Message id: [#{m.id}] Setting state to 'error'")
      m.delivered_in_error('Clean Active Messages')
    end
  end

  def log_destroy_of_worker_messages
    self.ready_messages.each do |m|
      $log.warn("MIQ(#{self.class.name}.log_destroy_of_worker_messages) Nullifying: #{MiqQueue.format_full_log_msg(m)}") rescue nil
      m.update_attributes(:handler_id => nil, :handler_type => nil) rescue nil
    end

    self.processed_messages.each do |m|
      $log.warn("MIQ(#{self.class.name}.log_destroy_of_worker_messages) Destroying: #{MiqQueue.format_full_log_msg(m)}") rescue nil
    end
  end

  def status_update
    begin
      pinfo = MiqProcess.processInfo(self.pid)
    rescue => err
      # Calling ps on Linux with a pid that does not exist fails with a RuntimeError containing an empty message.
      # We will ignore this since we may be asking for the status of a worker who has exited.
      $log.warn("MIQ(MiqWorker.status_update) #{self.class.name}: #{err.message}, while requesting process info for [#{self.friendly_name}] with PID=[#{self.pid}]") unless err.message.blank?
      return
    end

    # Ensure the hash only contains the values we want to store in the table
    pinfo.delete_if {|k,v| ![:priority, :memory_usage, :percent_memory, :percent_cpu, :memory_size, :cpu_time].include?(k)}
    pinfo[:os_priority] = pinfo.delete(:priority)
    self.update_attributes(pinfo)
  end

  def log_status(level=:info)
    $log.send(level, "MIQ(MiqWorker.log_status) #{self.class.name}: [#{self.friendly_name}] Worker ID [#{self.id}], PID [#{self.pid}], GUID [#{self.guid}], Last Heartbeat [#{self.last_heartbeat}], Process Info: Memory Usage [#{self.memory_usage}], Memory Size [#{self.memory_size}], Memory % [#{self.percent_memory}], CPU Time [#{self.cpu_time}], CPU % [#{self.percent_cpu}], Priority [#{self.os_priority}]")
  end

  def current_timeout
    msg = self.active_messages.first
    return msg.nil? ? nil : msg.msg_timeout
  end

  def uri_or_queue_name
    self.uri || self.queue_name
  end

  def friendly_name
    self.normalized_type.titleize
  end

  def normalized_type
    self.class.normalized_type
  end

  def format_full_log_msg
    "Worker [#{self.class}] with ID: [#{self.id}], PID: [#{self.pid}], GUID: [#{self.guid}]"
  end

  def format_short_log_msg
    "Worker ID: [#{self.id}]"
  end

  def self.release_db_connection
    ActiveRecord::Base.connection_pool.release_connection if ActiveRecord::Base.connected?
  end

  def update_heartbeat
    self.update_attribute(:last_heartbeat, Time.now.utc)
  end

  def is_current_process?
    Process.pid == self.pid
  end

  def self.config_settings_path
    @config_settings_path ||= [:workers] + self.path_to_my_worker_settings
  end

  def self.config_settings_path=(val)
    @config_settings_path = val
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    configuration.merge_from_template_if_missing(*config_settings_path) unless config_settings_path.empty?
  end

  def update_spid(spid = ActiveRecord::Base.connection.spid)
    self.sql_spid = spid
  end

  def update_spid!(spid = ActiveRecord::Base.connection.spid)
    if self.sql_spid != spid
      self.sql_spid = spid
      self.save
    end
  end

  protected

  def self.normalized_type
    @normalized_type ||= self.name[3..-1].underscore
  end

  def self.nice_prefix
    @nice_prefix ||= "nice -n #{self.nice_increment}"
  end

  def self.nice_increment
    delta = self.worker_settings[:nice_delta]
    delta.kind_of?(Integer) ? delta.to_s : "+10"
  end

  def self.build_command_line(*params)
    params = params.first || {}
    raise ArgumentError, "params must contain :guid" unless params.has_key?(:guid)

    rr = File.expand_path(Rails.root)

    cl = "#{self.nice_prefix} #{Gem.ruby}"
    cl << " " << File.join(rr, "bin/rails runner")
    cl << " " << File.join(rr, "lib/workers/bin/worker.rb #{self.corresponding_helper}")
    cl << " " << self.name
    params.each { |k, v| cl << " --#{k} \"#{v}\"" unless v.blank? }

    return cl
  end

  def command_line_params
    { :guid => self.guid }
  end

  def set_command_line
    self.command_line = self.class.build_command_line(self.command_line_params)
  end
end
