require 'timeout'
require 'digest'

# Message Queue entry to run a method on any server
#   zone
#     This states the subset of miq_servers in this region that can perform this job.
#     put: Defaults to the zone of the current caller ("MyZone")
#          Pass in nil to have this performed in any zone.
#     get: Fetches jobs both for the caller's zone and for any zone.
#   role
#     This states the role necessary for a miq_server to perform this job.
#     put: Defaults to nil (no role required).
#          Typically this is passed in to require a role.
#     get: Fetches jobs both for the caller's roles and for no role required.
#   queue_name
#     This states the worker queue that will perform this job.
#     put: Default to "generic" to be performed by the generic worker.
#     get: Defaults to "generic" but is typically overridden by the caller (a worker)
#
class MiqQueue < ApplicationRecord
  belongs_to :handler, :polymorphic => true
  belongs_to :miq_task

  attr_accessor :last_exception

  MAX_PRIORITY    = 0
  HIGH_PRIORITY   = 20
  NORMAL_PRIORITY = 100
  LOW_PRIORITY    = 150
  MIN_PRIORITY    = 200

  PRIORITY_WHICH  = [:max, :high, :normal, :low, :min]
  PRIORITY_DIR    = [:higher, :lower]

  def self.artemis_client(client_ref)
    @artemis_client ||= {}
    @artemis_client[client_ref] ||= begin
      require "manageiq-messaging"
      ManageIQ::Messaging.logger = _log
      queue_settings = Settings.prototype.artemis
      connect_opts = {
        :host       => ENV["ARTEMIS_QUEUE_HOSTNAME"] || queue_settings.queue_hostname,
        :port       => (ENV["ARTEMIS_QUEUE_PORT"] || queue_settings.queue_port).to_i,
        :username   => ENV["ARTEMIS_QUEUE_USERNAME"] || queue_settings.queue_username,
        :password   => ENV["ARTEMIS_QUEUE_PASSWORD"] || queue_settings.queue_password,
        :client_ref => client_ref,
      }

      # caching the client works, even if the connection becomes unavailable
      # internally the client will track the state of the connection and re-open it,
      # once it's available again - at least thats true for a stomp connection
      ManageIQ::Messaging::Client.open(connect_opts)
    end
  end

  def self.columns_for_requeue
    @requeue_columns ||= MiqQueue.column_names.map(&:to_sym) - [:id]
  end

  def self.priority(which, dir = nil, by = 0)
    unless which.kind_of?(Integer) || PRIORITY_WHICH.include?(which)
      raise ArgumentError,
            _("which must be an Integer or one of %{priority}") % {:priority => PRIORITY_WHICH.join(", ")}
    end
    unless dir.nil? || PRIORITY_DIR.include?(dir)
      raise ArgumentError, _("dir must be one of %{directory}") % {:directory => PRIORITY_DIR.join(", ")}
    end

    which = const_get("#{which.to_s.upcase}_PRIORITY") unless which.kind_of?(Integer)
    priority = which.send(dir == :higher ? "-" : "+", by)
    priority = MIN_PRIORITY if priority > MIN_PRIORITY
    priority = MAX_PRIORITY if priority < MAX_PRIORITY
    priority
  end

  def self.higher_priority(*priorities)
    priorities.min
  end

  def self.lower_priority(*priorities)
    priorities.max
  end

  def self.higher_priority?(p1, p2)
    p1 < p2
  end

  def self.lower_priority?(p1, p2)
    p1 > p2
  end

  TIMEOUT = 10.minutes

  serialize :args, Array
  serialize :miq_callback, Hash

  validates :zone, :inclusion => {:in => proc { Zone.in_my_region.pluck(:name) }}, :allow_nil => true

  STATE_READY   = 'ready'.freeze
  STATE_DEQUEUE = 'dequeue'.freeze
  STATE_WARN    = 'warn'.freeze
  STATE_ERROR   = 'error'.freeze
  STATE_TIMEOUT = 'timeout'.freeze
  STATE_EXPIRED = "expired".freeze
  validates_inclusion_of :state,  :in => [STATE_READY, STATE_DEQUEUE, STATE_WARN, STATE_ERROR, STATE_TIMEOUT, STATE_EXPIRED]
  FINISHED_STATES = [STATE_WARN, STATE_ERROR, STATE_TIMEOUT, STATE_EXPIRED].freeze

  STATUS_OK      = 'ok'.freeze
  STATUS_RETRY   = 'retry'.freeze
  STATUS_WARN    = STATE_WARN
  STATUS_ERROR   = STATE_ERROR
  STATUS_TIMEOUT = STATE_TIMEOUT
  DEFAULT_QUEUE  = "generic"

  def data
    msg_data && Marshal.load(msg_data)
  end

  def data=(value)
    self.msg_data = Marshal.dump(value)
  end

  def self.put(options)
    options = options.merge(
      :zone         => Zone.determine_queue_zone(options),
      :state        => STATE_READY,
      :handler_type => nil,
      :handler_id   => nil,
    )

    create_with_options = all.values[:create_with] || {}
    options[:priority]    ||= create_with_options[:priority] || NORMAL_PRIORITY
    options[:queue_name]  ||= create_with_options[:queue_name] || "generic"
    options[:msg_timeout] ||= create_with_options[:msg_timeout] || TIMEOUT
    options[:task_id]       = $_miq_worker_current_msg.try(:task_id) unless options.key?(:task_id)
    options[:tracking_label] = Thread.current[:tracking_label] || options[:task_id] unless options.key?(:tracking_label)
    options[:role]          = options[:role].to_s unless options[:role].nil?

    options[:args] = [options[:args]] if options[:args] && !options[:args].kind_of?(Array)

    if !Rails.env.production? && options[:args] &&
       (arg = options[:args].detect { |a| a.kind_of?(ActiveRecord::Base) && !a.new_record? })
      raise ArgumentError, "MiqQueue.put(:class_name => #{options[:class_name]}, :method => #{options[:method_name]}) does not support args with #{arg.class.name} objects"
    end

    msg = MiqQueue.create!(options)
    _log.info(MiqQueue.format_full_log_msg(msg))
    msg
  end

  # Trigger a background job
  #
  # target_worker:
  #
  # @options options [String] :class
  # @options options [String] :instance
  # @options options [String] :method
  # @options options [String] :args
  # @options options [String] :target_id (deprecated)
  # @options options [String] :data (deprecated)
  #
  # execution parameters:
  #
  # @options options [String] :expires_on
  # @options options [String] :ttl
  # @options options [String] :task_id (deprecated)
  #
  # routing:
  #
  # @options options [String] :service name of the service. Similar to previous role or queue name derives
  #                                    queue_name, role, and zone.
  # @options options [ExtManagementSystem|Nil|Array<Class,id>] :affinity resource for affinity. Typically an ems
  # @options options [String] :miq_zone this overrides the auto derived zone.
  #
  def self.submit_job(options)
    service = options.delete(:service) || "generic"
    resource = options.delete(:affinity)
    case service
    when "automate"
      # options[:queue_name] = "generic"
      options[:role] = service
    when "ems_inventory"
      options[:queue_name] = MiqEmsRefreshWorker.queue_name_for_ems(resource)
      options[:role]       = service
      options[:zone]       = resource.my_zone
    when "ems_operations", "smartstate"
      # ems_operations, refresh is class method
      # some smartstate just want MiqServer.my_zone and pass in no resource
      # options[:queue_name] = "generic"
      options[:role] = service
      options[:zone] = resource.try(:my_zone) || MiqServer.my_zone
    when "event"
      options[:queue_name] = "ems"
      options[:role] = service
    when "generic"
      raise ArgumentError, "generic job should have no resource" if resource
      # TODO: can we transition to zone = nil
    when "notifier"
      options[:role] = service
      options[:zone] = nil # any zone
    when "reporting"
      options[:queue_name] = "generic"
      options[:role] = service
    when "smartproxy"
      options[:queue_name] = "smartproxy"
      options[:role] = "smartproxy"
    end
    put(options)
  end

  def self.where_queue_name(is_array)
    is_array ? "AND queue_name in (?)" : "AND queue_name = ?"
  end

  MIQ_QUEUE_GET = <<-EOL
    state = 'ready'
    AND (zone IS NULL OR zone = ?)
    AND (task_id IS NULL OR task_id NOT IN (
      SELECT DISTINCT task_id
      FROM #{table_name}
      WHERE state = 'dequeue'
        AND (zone IS NULL OR zone = ?)
        AND task_id IS NOT NULL
    ))
    AND (role IS NULL OR role IN (?))
    AND (server_guid IS NULL OR server_guid = ?)
    AND (deliver_on IS NULL OR deliver_on <= ?)
    AND (priority <= ?)
  EOL

  def self.get(options = {})
    sql_for_get = MIQ_QUEUE_GET + where_queue_name(options[:queue_name].kind_of?(Array))
    cond = [
      sql_for_get,
      options[:zone] || MiqServer.my_server.zone.name,
      options[:zone] || MiqServer.my_server.zone.name,
      options[:role] || MiqServer.my_server.active_role_names,
      MiqServer.my_guid,
      Time.now.utc,
      options[:priority] || MIN_PRIORITY,
      options[:queue_name] || "generic",
    ]

    prefetch_max_per_worker = Settings.server.prefetch_max_per_worker
    msgs = MiqQueue.where(cond).order("priority, id").limit(prefetch_max_per_worker)

    result = nil
    msgs.each do |msg|
      begin
        _log.info("#{MiqQueue.format_short_log_msg(msg)} previously timed out, retrying...") if msg.state == STATE_TIMEOUT
        handler = MiqWorker.my_worker || MiqServer.my_server
        msg.update_attributes!(:state => STATE_DEQUEUE, :handler => handler)
        _log.info("#{MiqQueue.format_full_log_msg(msg)}, Dequeued in: [#{Time.now.utc - msg.created_on}] seconds")
        return msg
      rescue ActiveRecord::StaleObjectError
        result = :stale
      rescue => err
        raise _("%{log_message} \"%{error}\" attempting to get next message") % {:log_message => _log.prefix, :error => err}
      end
    end
    _log.debug("All #{prefetch_max_per_worker} messages stale, returning...") if result == :stale
    result
  end

  # This are the queue calls related to worker management which
  # might not be needed once we use kubernetes for worker/pod management
  def self.put_deprecated(*args)
    put(*args)
  end

  def unget(options = {})
    update_attributes!(options.merge(:state => STATE_READY, :handler => nil))
    @delivered_on = nil
    _log.info("#{MiqQueue.format_full_log_msg(self)}, Requeued")
  end

  # TODO (juliancheal) This is a hack. Brakeman was giving us an SQL injection
  # warning when we concatonated the queue_name string onto the query.
  # Creating two seperate queries like this, resolves the Brakeman issue, but
  # isn't ideal. This will need to be rewritten using Arel queries at some point.

  MIQ_QUEUE_PEEK = <<-EOL
    state = 'ready'
    AND (zone IS NULL OR zone = ?)
    AND (role IS NULL OR role IN (?))
    AND (server_guid IS NULL OR server_guid = ?)
    AND (deliver_on IS NULL OR deliver_on <= ?)
    AND (priority <= ?)
    AND queue_name = ?
  EOL

  MIQ_QUEUE_PEEK_ARRAY = <<-EOL
    state = 'ready'
    AND (zone IS NULL OR zone = ?)
    AND (role IS NULL OR role IN (?))
    AND (server_guid IS NULL OR server_guid = ?)
    AND (deliver_on IS NULL OR deliver_on <= ?)
    AND (priority <= ?)
    AND queue_name in (?)
  EOL

  def self.peek(options = {})
    conditions, select, limit = options.values_at(:conditions, :select, :limit)

    sql_for_peek = conditions[:queue_name].kind_of?(Array) ? MIQ_QUEUE_PEEK_ARRAY : MIQ_QUEUE_PEEK

    cond = [
      sql_for_peek,
      conditions[:zone] || MiqServer.my_server.zone.name,
      conditions[:role] || MiqServer.my_server.active_role_names,
      MiqServer.my_guid,
      Time.now.utc,
      conditions[:priority] || MIN_PRIORITY,
      conditions[:queue_name] || "generic",
    ]

    result = MiqQueue.where(cond).order(:priority, :id).limit(limit || 1)
    result = result.select(select) unless select.nil?
    result.to_a
  end

  # Find the MiqQueue item with the specified find options, and yields that
  #   record to a block.  The block should return the options for updating
  #   the record.  If the record was not found, the block's options will be
  #   used to put a new item on the queue.
  #
  def self.put_or_update(find_options)
    find_options = default_get_options(find_options)

    # Since args are a serializable field, remove them and manually dump them
    #   for proper comparison.
    where_scope =
      if find_options.key?(:args)
        MiqQueue.where(find_options.except(:args)).where(['args = ?', find_options[:args].try(:to_yaml)])
      else
        MiqQueue.where(find_options)
      end

    msg = nil
    loop do
      msg = where_scope.order("priority, id").first

      save_options = block_given? ? yield(msg, find_options) : nil

      # Add a new queue item based on the returned save options, or the find
      #   options if no save options were given.
      if msg.nil?
        put_options = save_options || find_options
        put_options = put_options.except(:state) if put_options.key?(:state)
        msg = MiqQueue.put(put_options)
        break
      end

      begin
        # Update the queue item based on the returned save options.
        unless save_options.nil?
          if save_options.key?(:msg_timeout) && (msg.msg_timeout > save_options[:msg_timeout])
            _log.warn("#{MiqQueue.format_short_log_msg(msg)} ignoring request to decrease timeout from <#{msg.msg_timeout}> to <#{save_options[:msg_timeout]}>")
            save_options = save_options.except(:msg_timeout)
          end

          msg.update_attributes!(save_options)
          _log.info("#{MiqQueue.format_short_log_msg(msg)} updated with following: #{save_options.except(:data, :msg_data).inspect}")
          _log.info("#{MiqQueue.format_full_log_msg(msg)}, Requeued")
        end
        break
      rescue ActiveRecord::StaleObjectError
        _log.debug("#{MiqQueue.format_short_log_msg(msg)} stale, retrying...")
      rescue => err
        raise RuntimeError,
              _("%{log_message} \"%{error}\" attempting merge next message") % {:log_message => _log.prefix,
                                                                                :error       => err},
              err.backtrace
      end
    end
    msg
  end

  # Find the MiqQueue item with the specified find options, and if not found
  #   puts a new item on the queue.  If the item was found, it will not be
  #   changed, and will be yielded to an optional block, generally for logging
  #   purposes.
  def self.put_unless_exists(find_options)
    put_or_update(find_options) do |msg, item_hash|
      ret = yield(msg, item_hash) if block_given?
      # create the record if the original message did not exist, don't change otherwise
      ret if msg.nil?
    end
  end

  def self.unqueue(options)
    find_by(optional_values(default_get_options(options))).try(:destroy)
  end

  def deliver(requester = nil)
    result = nil
    delivered_on
    _log.info("#{MiqQueue.format_short_log_msg(self)}, Delivering...")

    begin
      raise _("class_name cannot be nil") if class_name.nil?

      obj = class_name.constantize

      if instance_id
        begin
          if (class_name == requester.class.name) && requester.respond_to?(:id) && (instance_id == requester.id)
            obj = requester
          else
            obj = obj.find(instance_id)
          end
        rescue ActiveRecord::RecordNotFound => err
          _log.warn("#{MiqQueue.format_short_log_msg(self)} will not be delivered because #{err.message}")
          return STATUS_WARN, nil, nil
        rescue => err
          _log.error("#{MiqQueue.format_short_log_msg(self)} will not be delivered because #{err.message}")
          return STATUS_ERROR, err.message, nil
        end
      end

      data = self.data
      args.push(data) if data
      args.unshift(target_id) if obj.kind_of?(Class) && target_id

      begin
        status = STATUS_OK
        message = "Message delivered successfully"
        result = User.with_user_group(user_id, group_id) { dispatch_method(obj, args) }
      rescue MiqException::MiqQueueRetryLater => err
        unget(err.options)
        message = "Message not processed.  Retrying #{err.options[:deliver_on] ? "at #{err.options[:deliver_on]}" : 'immediately'}"
        _log.error("#{MiqQueue.format_short_log_msg(self)}, #{message}")
        status = STATUS_RETRY
      rescue Timeout::Error
        message = "timed out after #{Time.now - delivered_on} seconds.  Timeout threshold [#{msg_timeout}]"
        _log.error("#{MiqQueue.format_short_log_msg(self)}, #{message}")
        status = STATUS_TIMEOUT
      end
    rescue StandardError, SyntaxError => error
      _log.error("#{MiqQueue.format_short_log_msg(self)}, Error: [#{error}]")
      _log.log_backtrace(error) unless error.kind_of?(MiqException::Error)
      status = STATUS_ERROR
      self.last_exception = error
      message = error.message
    end

    return status, message, result
  end

  def dispatch_method(obj, args)
    Timeout.timeout(msg_timeout) do
      args = activate_miq_task(args)
      obj.send(method_name, *args)
    end
  end

  DELIVER_IN_ERROR_MSG = 'Deliver in error'.freeze
  def delivered_in_error(msg = nil)
    delivered('error', msg || DELIVER_IN_ERROR_MSG, nil)
  end

  def delivered(state, msg, result)
    self.state = state
    _log.info("#{MiqQueue.format_short_log_msg(self)}, State: [#{state}], Delivered in [#{Time.now - delivered_on}] seconds")
    m_callback(msg, result) unless miq_callback.blank?
  rescue => err
    _log.error("#{MiqQueue.format_short_log_msg(self)}, #{err.message}")
  ensure
    destroy_potentially_stale_record
  end

  def delivered_on
    @delivered_on ||= Time.now
  end

  def m_callback(msg, result)
    if miq_callback[:class_name] && miq_callback[:method_name]
      begin
        klass = miq_callback[:class_name].constantize
        if miq_callback[:instance_id]
          obj = klass.find(miq_callback[:instance_id])
        else
          obj = klass
          _log.debug("#{MiqQueue.format_short_log_msg(self)}, Could not find callback in Class: [#{miq_callback[:class_name]}]") unless obj
        end
        if obj.respond_to?(miq_callback[:method_name])
          miq_callback[:args] ||= []

          log_args = result.inspect
          log_args = "#{log_args[0, 500]}..." if log_args.length > 500  # Trim long results
          log_args = miq_callback[:args] + [state, msg, log_args]
          _log.info("#{MiqQueue.format_short_log_msg(self)}, Invoking Callback with args: #{log_args.inspect}") unless obj.nil?

          cb_args = miq_callback[:args] + [state, msg, result]
          cb_args << self if cb_args.length == (obj.method(miq_callback[:method_name]).arity - 1)
          obj.send(miq_callback[:method_name], *cb_args)
        else
          _log.warn("#{MiqQueue.format_short_log_msg(self)}, Instance: [#{obj}], does not respond to Method: [#{miq_callback[:method_name]}], skipping")
        end
      rescue => err
        _log.error("#{MiqQueue.format_short_log_msg(self)}: #{err}")
        _log.log_backtrace(err)
      end
    else
      _log.warn("#{MiqQueue.format_short_log_msg(self)}, Callback is not well-defined, skipping")
    end
  end

  def requeue(options = {})
    options.reverse_merge!(attributes.symbolize_keys)
    MiqQueue.put(options.slice(*MiqQueue.columns_for_requeue))
  end

  def check_for_timeout(log_prefix = "MIQ(MiqQueue.check_for_timeout)", grace = 10.seconds, timeout = msg_timeout.seconds)
    if state == 'dequeue' && Time.now.utc > (updated_on + timeout.seconds + grace.seconds).utc
      msg = " processed by #{handler.format_full_log_msg}" unless handler.nil?
      $log.warn("#{log_prefix} Timed Out Active #{MiqQueue.format_short_log_msg(self)}#{msg} after #{Time.now.utc - updated_on} seconds")
      destroy rescue nil
    end
  end

  def finished?
    FINISHED_STATES.include?(state)
  end

  def unfinished?
    !finished?
  end

  def self.format_full_log_msg(msg)
    "Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], MiqTask id: [#{msg.miq_task_id}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{MiqPassword.sanitize_string(msg.args.inspect)}"
  end

  def self.format_short_log_msg(msg)
    "Message id: [#{msg.id}]"
  end

  def get_worker
    handler if handler.kind_of?(MiqWorker)
  end

  def self.get_worker(task_id)
    find_by(:task_id => task_id).try(:get_worker)
  end

  def self.display_name(number = 1)
    n_('Queue', 'Queues', number)
  end

  private

  def activate_miq_task(args)
    MiqTask.update_status(miq_task_id, MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "Task starting") if miq_task_id
    params = args.first
    params[:miq_task_id] = miq_task_id if params.kind_of?(Hash)
    args
  end

  # default values for get operations
  def self.default_get_options(options)
    options.reverse_merge(
      :queue_name => DEFAULT_QUEUE,
      :state      => STATE_READY,
      :zone       => Zone.determine_queue_zone(options)
    )
  end

  # when searching miq_queue, we often want to see if a key is nil, or a particular value
  # given a set of keys, modify the params to have those values
  # example:
  #   optional_values({:a => 'x', :b => 'y'}, [:a])
  #     # => {:a => [nil, 'x'], :b => 'y'}
  #   sql => "where (a is nil or a = 'x') and b = 'y'"
  #
  def self.optional_values(options, keys = [:zone])
    options = options.dup
    Array(keys).each do |key|
      options[key] = [nil, options[key]].uniq if options.key?(key)
    end
    options
  end

  def destroy_potentially_stale_record
    destroy
  rescue ActiveRecord::StaleObjectError
    begin
      reload.destroy
    rescue ActiveRecord::RecordNotFound
      # ignore
    end
  end
end # Class MiqQueue
