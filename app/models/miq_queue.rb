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

  attr_accessor :last_exception

  MAX_PRIORITY    = 0
  HIGH_PRIORITY   = 20
  NORMAL_PRIORITY = 100
  LOW_PRIORITY    = 150
  MIN_PRIORITY    = 200

  PRIORITY_WHICH  = [:max, :high, :normal, :low, :min]
  PRIORITY_DIR    = [:higher, :lower]

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
  STATUS_EXPIRED = STATE_EXPIRED
  DEFAULT_QUEUE  = "generic"

  def data
    msg_data && Marshal.load(msg_data)
  end

  def data=(value)
    self.msg_data = Marshal.dump(value)
  end

  def self.put(options)
    options = options.reverse_merge(
      :priority     => NORMAL_PRIORITY,
      :queue_name   => "generic",
      :role         => nil,
      :server_guid  => nil,
      :msg_timeout  => TIMEOUT,
      :deliver_on   => nil
    ).merge(
      :zone         => Zone.determine_queue_zone(options),
      :state        => STATE_READY,
      :handler_type => nil,
      :handler_id   => nil,
    )
    options[:task_id]      = $_miq_worker_current_msg.try(:task_id) unless options.key?(:task_id)
    options[:role]         = options[:role].to_s unless options[:role].nil?

    options[:args] = [options[:args]] if options[:args] && !options[:args].kind_of?(Array)

    if !Rails.env.production? && options[:args] &&
       (arg = options[:args].detect { |a| a.kind_of?(ActiveRecord::Base) && !a.new_record? })
      raise ArgumentError, "MiqQueue.put(:class_name => #{options[:class_name]}, :method => #{options[:method_name]}) does not support args with #{arg.class.name} objects"
    end

    msg = MiqQueue.create!(options)
    _log.info(MiqQueue.format_full_log_msg(msg))
    msg
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
    AND queue_name = ?
    AND (role IS NULL OR role IN (?))
    AND (server_guid IS NULL OR server_guid = ?)
    AND (deliver_on IS NULL OR deliver_on <= ?)
    AND (priority <= ?)
  EOL

  def self.get(options = {})
    cond = [
      MIQ_QUEUE_GET,
      options[:zone] || MiqServer.my_server.zone.name,
      options[:zone] || MiqServer.my_server.zone.name,
      options[:queue_name] || "generic",
      options[:role] || MiqServer.my_server.active_role_names,
      MiqServer.my_guid,
      Time.now.utc,
      options[:priority] || MIN_PRIORITY,
    ]

    prefetch_max_per_worker = Settings.server.prefetch_max_per_worker
    msgs = MiqQueue.where(cond).order("priority, id").limit(prefetch_max_per_worker)
    return nil if msgs.empty? # Nothing available in the queue

    result = nil
    msgs.each do |msg|
      begin
        _log.info("#{MiqQueue.format_short_log_msg(msg)} previously timed out, retrying...") if msg.state == STATE_TIMEOUT
        w = MiqWorker.server_scope.find_by(:pid => Process.pid)
        if w.nil?
          msg.update_attributes!(:state => STATE_DEQUEUE, :handler => MiqServer.my_server)
        else
          msg.update_attributes!(:state => STATE_DEQUEUE, :handler => w)
        end
        result = msg
        break
      rescue ActiveRecord::StaleObjectError
        result = :stale
      rescue => err
        raise _("%{log_message} \"%{error}\" attempting to get next message") % {:log_message => _log.prefix, :error => err}
      end
    end
    if result == :stale
      _log.debug("All #{prefetch_max_per_worker} messages stale, returning...")
    else
      _log.info("#{MiqQueue.format_full_log_msg(result)}, Dequeued in: [#{Time.now - result.created_on}] seconds")
    end
    result
  end

  def unget(options = {})
    update_attributes!(options.merge(:state => STATE_READY, :handler => nil))
    @delivered_on = nil
    _log.info("#{MiqQueue.format_full_log_msg(self)}, Requeued")
  end

  MIQ_QUEUE_PEEK = <<-EOL
    state = 'ready'
    AND (zone IS NULL OR zone = ?)
    AND queue_name = ?
    AND (role IS NULL OR role IN (?))
    AND (server_guid IS NULL OR server_guid = ?)
    AND (deliver_on IS NULL OR deliver_on <= ?)
    AND (priority <= ?)
  EOL

  def self.peek(options = {})
    conditions, select, limit = options.values_at(:conditions, :select, :limit)

    cond = [
      MIQ_QUEUE_PEEK,
      conditions[:zone] || MiqServer.my_server.zone.name,
      conditions[:queue_name] || "generic",
      conditions[:role] || MiqServer.my_server.active_role_names,
      MiqServer.my_guid,
      Time.now.utc,
      conditions[:priority] || MIN_PRIORITY,
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
  #   The find options may also contain an optional :args_selector proc that
  #   will allow multiple records found by the find options to further be
  #   searched against the args column, which is normally not easily searchable.
  def self.put_or_update(find_options)
    find_options  = default_get_options(find_options)
    args_selector = find_options.delete(:args_selector)
    conds = find_options.dup

    # Since args are a serializable field, remove them and manually dump them
    #   for proper comparison.  NOTE: hashes may not compare correctly due to
    #   it's unordered nature.
    where_scope = if conds.key?(:args)
                    args = YAML.dump conds.delete(:args)
                    MiqQueue.where(conds).where(['args = ?', args])
                  else
                    MiqQueue.where(conds)
                  end

    msg = nil
    loop do
      msg = if args_selector
              where_scope.order("priority, id").detect { |m| args_selector.call(m.args) }
            else
              where_scope.order("priority, id").first
            end

      save_options = block_given? ? yield(msg, find_options) : nil
      unless save_options.nil?
        save_options = save_options.dup
        save_options.delete(:args_selector)
      end

      # Add a new queue item based on the returned save options, or the find
      #   options if no save options were given.
      if msg.nil?
        put_options = save_options || find_options
        put_options.delete(:state)
        msg = MiqQueue.put(put_options)
        break
      end

      begin
        # Update the queue item based on the returned save options.
        unless save_options.nil?
          if save_options.key?(:msg_timeout) && (msg.msg_timeout > save_options[:msg_timeout])
            _log.warn("#{MiqQueue.format_short_log_msg(msg)} ignoring request to decrease timeout from <#{msg.msg_timeout}> to <#{save_options[:msg_timeout]}>")
            save_options.delete(:msg_timeout)
          end

          msg.update_attributes!(save_options)
          _log.info("#{MiqQueue.format_short_log_msg(msg)} updated with following: #{save_options.inspect}")
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
      raise MiqException::MiqQueueExpired if expires_on && (Time.now.utc > expires_on)

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
          _log.warn  "#{MiqQueue.format_short_log_msg(self)} will not be delivered because #{err.message}"
          return STATUS_WARN, nil, nil
        rescue => err
          _log.error "#{MiqQueue.format_short_log_msg(self)} will not be delivered because #{err.message}"
          return STATUS_ERROR, err.message, nil
        end
      end

      data = self.data
      args.push(data) if data

      begin
        status = STATUS_OK
        message = "Message delivered successfully"
        Timeout.timeout(msg_timeout) do
          if obj.kind_of?(Class) && !target_id.nil?
            result = obj.send(method_name, target_id, *args)
          else
            result = obj.send(method_name, *args)
          end
        end
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
    rescue MiqException::MiqQueueExpired
      message = "Expired on [#{expires_on}]"
      _log.error("#{MiqQueue.format_short_log_msg(self)}, #{message}")
      status = STATUS_EXPIRED
    rescue StandardError, SyntaxError => error
      _log.error("#{MiqQueue.format_short_log_msg(self)}, Error: [#{error}]")
      _log.log_backtrace(error) unless error.kind_of?(MiqException::Error)
      status = STATUS_ERROR
      self.last_exception = error
      message = error.message
    end

    return status, message, result
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
        _log.error("backtrace: #{err.backtrace.join("\n")}")
      end
    else
      _log.warn "#{MiqQueue.format_short_log_msg(self)}, Callback is not well-defined, skipping"
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

  def self.atStartup
    _log.info("Cleaning up queue messages...")
    MiqQueue.where(:state => STATE_DEQUEUE).each do |message|
      if message.handler.nil?
        _log.warn("Cleaning message in dequeue state without worker: #{format_full_log_msg(message)}")
      else
        handler_server = message.handler            if message.handler.kind_of?(MiqServer)
        handler_server = message.handler.miq_server if message.handler.kind_of?(MiqWorker)
        next unless handler_server == MiqServer.my_server

        _log.warn("Cleaning message: #{format_full_log_msg(message)}")
      end
      message.update_attributes(:state => STATE_ERROR) rescue nil
    end
    _log.info("Cleaning up queue messages... Complete")
  end

  def self.format_full_log_msg(msg)
    "Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{MiqPassword.sanitize_string(msg.args.inspect)}"
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

  private

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
