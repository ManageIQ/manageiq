require 'timeout'
require 'digest'

require 'miq_queue/constants'
require 'miq_queue/format_methods'
require 'miq_queue/put_methods'

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

  include MiqQueueConstants

  extend MiqQueueFormatMethods
  extend MiqQueuePutMethods

  belongs_to :handler, :polymorphic => true

  attr_accessor :last_exception

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

  serialize :args, Array
  serialize :miq_callback, Hash

  validates_inclusion_of :state,  :in => [STATE_READY, STATE_DEQUEUE, STATE_WARN, STATE_ERROR, STATE_TIMEOUT, STATE_EXPIRED]

  def data
    msg_data && Marshal.load(msg_data)
  end

  def data=(value)
    self.msg_data = Marshal.dump(value)
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

  def get_worker
    handler if handler.kind_of?(MiqWorker)
  end

  def self.get_worker(task_id)
    find_by(:task_id => task_id).try(:get_worker)
  end

  private

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
