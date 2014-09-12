require 'timeout'
require 'digest'

class MiqQueue < ActiveRecord::Base
  include DontAutoSaveSerialized

  belongs_to :handler, :polymorphic => true

  attr_accessor :last_exception

  MAX_PRIORITY    = 0
  HIGH_PRIORITY   = 20
  NORMAL_PRIORITY = 100
  LOW_PRIORITY    = 150
  MIN_PRIORITY    = 200

  PRIORITY_WHICH  = [:max, :high, :normal, :low, :min]
  PRIORITY_DIR    = [:higher, :lower]

  def self.priority(which, dir = nil, by = 0)
    raise ArgumentError, "which must be an Integer or one of #{PRIORITY_WHICH.join(", ")}" unless which.kind_of?(Integer) || PRIORITY_WHICH.include?(which)
    raise ArgumentError, "dir must be one of #{PRIORITY_DIR.join(", ")}" unless dir.nil? || PRIORITY_DIR.include?(dir)

    which = self.const_get("#{which.to_s.upcase}_PRIORITY") unless which.kind_of?(Integer)
    priority = which.send(dir == :higher ? "-" : "+", by)
    priority = MIN_PRIORITY if priority > MIN_PRIORITY
    priority = MAX_PRIORITY if priority < MAX_PRIORITY
    return priority
  end

  def self.higher_priority(*priorities)
    return priorities.min
  end

  def self.lower_priority(*priorities)
    return priorities.max
  end

  def self.higher_priority?(p1, p2)
    p1 < p2
  end

  def self.lower_priority?(p1, p2)
    p1 > p2
  end

  TIMEOUT = 10.minutes

  serialize :args
  serialize :miq_callback

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

  @@delete_command_file = File.join(File.expand_path(Rails.root), "miq_queue_delete_cmd_file")

  LOG_PREFIX = {
    :put       => "MIQ(MiqQueue.put)       ",
    :get       => "MIQ(MiqQueue.get)       ",
    :unget     => "MIQ(MiqQueue.unget)     ",
    :deliver   => "MIQ(MiqQueue.deliver)   ",
    :delivered => "MIQ(MiqQueue.delivered) ",
    :merge     => "MIQ(MiqQueue.merge)     ",
    :callback  => "MIQ(MiqQueue.m_callback)",
    :atStartup => "MIQ(MiqQueue.atStartup) ",
    :dev_null  => "MIQ(MiqQueue.dev_null)  ",
  }

  def data
    return nil if self.msg_data.nil?
    Marshal.load(self.msg_data)
  end

  def data=(value)
    self.msg_data = Marshal.dump(value)
  end

  def warn_if_large_payload
    args_size = args ? YAML.dump(args).length : 0
    data_size = data ? data.length : 0

    if (args_size + data_size) > 512
      log_prefix=LOG_PREFIX[:put]
      culprit = caller.detect {|r| ! (r =~ /miq_queue.rb/) } || ""
      $log.warn("#{log_prefix} #{culprit.split(":in ").first} called with large payload (args: #{args_size} bytes, data: #{data_size} bytes) #{MiqQueue.format_full_log_msg(self)}")
    end
  end

  def self.put(options)
    log_prefix = LOG_PREFIX[:put]
    options = options.reverse_merge(
      :args         => [],
      :miq_callback => {},
      :priority     => NORMAL_PRIORITY,
      :queue_name   => "generic",
      :role         => nil,
      :server_guid  => nil,
      :msg_timeout  => TIMEOUT,
      :deliver_on   => nil
    )
    options[:zone]         = Zone.determine_queue_zone(options)
    options[:state]        = STATE_READY
    options[:handler_type] = nil
    options[:handler_id]   = nil
    options[:task_id]      = $_miq_worker_current_msg.try(:task_id) unless options.has_key?(:task_id)
    options[:role]         = options[:role].to_s unless options[:role].nil?

    msg = MiqQueue.create!(options)
    msg.warn_if_large_payload
    $log.info("#{log_prefix} #{MiqQueue.format_full_log_msg(msg)}")
    return msg
  end

  cache_with_timeout(:vmdb_config) { VMDB::Config.new("vmdb") }

  MIQ_QUEUE_GET = <<-EOL
    state = 'ready'
    AND (zone IS NULL OR zone = ?)
    AND (task_id IS NULL OR task_id NOT IN (
      SELECT DISTINCT task_id
      FROM #{self.table_name}
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

  def self.get(options={})
    log_prefix = LOG_PREFIX[:get]
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

    prefetch_max_per_worker = self.vmdb_config.config[:server][:prefetch_max_per_worker] || 10
    msgs = MiqQueue.find(:all, :conditions => cond, :order => "priority, id", :limit => prefetch_max_per_worker)
    return nil if msgs.empty? # Nothing available in the queue

    result = nil
    msgs.each do |msg|
      begin
        $log.info("#{log_prefix} #{MiqQueue.format_short_log_msg(msg)} previously timed out, retrying...") if msg.state == STATE_TIMEOUT
        w = MiqWorker.server_scope.find_by_pid(Process.pid)
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
        raise "#{log_prefix} \"#{err}\" attempting to get next message"
      end
    end
    if result == :stale
      $log.debug("#{log_prefix} All #{prefetch_max_per_worker} messages stale, returning...")
    else
      $log.info("#{log_prefix} #{MiqQueue.format_full_log_msg(result)}, Dequeued in: [#{Time.now - result.created_on}] seconds")
    end
    return result
  end

  def unget(options = {})
    log_prefix = LOG_PREFIX[:unget]
    ar_options = options.dup
    ar_options[:state]   = 'ready'
    ar_options[:handler] = nil
    self.update_attributes!(ar_options)
    @delivered_on = nil
    $log.info("#{log_prefix} #{MiqQueue.format_full_log_msg(self)}, Requeued")
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

    args = { :conditions => cond, :order => "priority, id" }
    args[:select] = select unless select.nil?
    args[:limit]  = limit || 1
    MiqQueue.all(args)
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
    log_prefix = LOG_PREFIX[:merge]

    find_options  = default_get_options(find_options)
    args_selector = find_options.delete(:args_selector)

    # Since args are a serializable field, remove them and manually dump them
    #   for proper comparison.  NOTE: hashes may not compare correctly due to
    #   it's unordered nature.
    has_args = find_options.has_key?(:args)
    args = find_options.delete(:args) if has_args

    conds = [self.sanitize_sql_for_conditions(find_options)]
    if has_args
      conds[0] << " AND args = ?"
      conds << YAML.dump(args)
    end

    find_options[:args] = args if has_args

    msg = nil
    loop do
      msg = if args_selector
        MiqQueue.all(:conditions => conds, :order => "priority, id").detect { |m| args_selector.call(m.args) }
      else
        MiqQueue.first(:conditions => conds, :order => "priority, id")
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
          if save_options.has_key?(:msg_timeout) && (msg.msg_timeout > save_options[:msg_timeout])
            $log.warn("#{log_prefix} #{MiqQueue.format_short_log_msg(msg)} ignoring request to decrease timeout from <#{msg.msg_timeout}> to <#{save_options[:msg_timeout]}>")
            save_options.delete(:msg_timeout)
          end

          msg.update_attributes!(save_options)
          $log.info("#{log_prefix} #{MiqQueue.format_short_log_msg(msg)} updated with following: #{save_options.inspect}")
          $log.info("#{log_prefix} #{MiqQueue.format_full_log_msg(msg)}, Requeued")
        end
        break
      rescue ActiveRecord::StaleObjectError
        $log.debug("#{log_prefix} #{MiqQueue.format_short_log_msg(msg)} stale, retrying...")
      rescue => err
        raise "#{log_prefix} \"#{err}\" attempting merge next message"
      end
    end
    return msg
  end
  class << self
    alias_method :merge, :put_or_update
  end

  # Find the MiqQueue item with the specified find options, and if not found
  #   puts a new item on the queue.  If the item was found, it will not be
  #   changed, and will be yielded to an optional block, generally for logging
  #   purposes.
  def self.put_unless_exists(find_options)
    self.put_or_update(find_options) do |msg, item_hash|
      ret = yield(msg, item_hash) if block_given?
      # create the record if the original message did not exist, don't change otherwise
      ret if msg.nil?
    end
  end

  def self.unqueue(options)
    where(optional_values(default_get_options(options))).first.try(:destroy)
  end

  def deliver(requester = nil)
    log_prefix = LOG_PREFIX[:deliver]
    result = nil
    self.delivered_on
    $log.info("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, Delivering...")

    begin
      raise MiqException::MiqQueueExpired if self.expires_on && (Time.now.utc > self.expires_on)

      raise "class_name cannot be nil" if self.class_name.nil?

      obj = self.class_name.constantize

      if self.instance_id
        begin
          if (self.class_name == requester.class.name) && requester.respond_to?(:id) && (self.instance_id == requester.id)
            obj = requester
          else
            obj = obj.find(self.instance_id)
          end
        rescue ActiveRecord::RecordNotFound => err
          $log.warn  "#{log_prefix} #{MiqQueue.format_short_log_msg(self)} will not be delivered because #{err.message}"
          return STATUS_WARN, nil, nil
        rescue => err
          $log.error "#{log_prefix} #{MiqQueue.format_short_log_msg(self)} will not be delivered because #{err.message}"
          return STATUS_ERROR, err.message, nil
        end
      end

      data = self.data
      args.push(data) if data

      begin
        status = STATUS_OK
        message = "Message delivered successfully"
        Timeout::timeout(self.msg_timeout) do
          if obj.is_a?(Class) && !self.target_id.nil?
            result = obj.send(self.method_name, self.target_id, *args)
          else
            result = obj.send(self.method_name, *args)
          end
        end
      rescue MiqException::MiqQueueRetryLater => err
        self.unget(err.options)
        message = "Message not processed.  Retrying #{err.options[:deliver_on] ? "at #{err.options[:deliver_on]}" : 'immediately'}"
        $log.error("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, #{message}")
        status = STATUS_RETRY
      rescue TimeoutError
        message = "timed out after #{Time.now - self.delivered_on} seconds.  Timeout threshold [#{self.msg_timeout}]"
        $log.error("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, #{message}")
        status = STATUS_TIMEOUT
      end
    rescue SystemExit
      raise
    rescue MiqException::MiqQueueExpired
      message = "Expired on [#{self.expires_on}]"
      $log.error("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, #{message}")
      status = STATUS_EXPIRED
    rescue Exception => error
      $log.error("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, Error: [#{error}]")
      $log.log_backtrace(error) unless error.kind_of?(MiqException::Error)
      status = STATUS_ERROR
      self.last_exception = error
      message = error.message
    end

    return status, message, result
  end

  DELIVER_IN_ERROR_MSG = 'Deliver in error'.freeze
  def delivered_in_error(msg = nil)
    self.delivered('error', msg || DELIVER_IN_ERROR_MSG, nil)
  end

  def delivered(state, msg, result)
    begin
      log_prefix = LOG_PREFIX[:delivered]
      self.state = state
      $log.info("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, State: [#{state}], Delivered in [#{Time.now - self.delivered_on}] seconds")
      m_callback(msg, result) unless self.miq_callback.blank?
    rescue => err
      $log.error("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, #{err.message}")
    ensure
      self.destroy
    end
  end

  def delivered_on
    @delivered_on ||= Time.now
  end

  def m_callback(msg, result)
    log_prefix = LOG_PREFIX[:callback]
    if self.miq_callback[:class_name] && self.miq_callback[:method_name]
      begin
        klass = self.miq_callback[:class_name].constantize
        if self.miq_callback[:instance_id]
          obj = klass.find(self.miq_callback[:instance_id])
        else
          obj = klass
          $log.debug("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, Could not find callback in Class: [#{self.miq_callback[:class_name]}]") unless obj
        end
        if obj.respond_to?(self.miq_callback[:method_name])
          self.miq_callback[:args] ||= []

          log_args = result.inspect
          log_args = "#{log_args[0, 500]}..." if log_args.length > 500  # Trim long results
          log_args = self.miq_callback[:args] + [self.state, msg, log_args]
          $log.info("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, Invoking Callback with args: #{log_args.inspect}") unless obj.nil?

          cb_args = self.miq_callback[:args] + [self.state, msg, result]
          cb_args << self if cb_args.length == (obj.method(self.miq_callback[:method_name]).arity - 1)
          obj.send(self.miq_callback[:method_name], *cb_args)
        else
          $log.warn("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, Instance: [#{obj}], does not respond to Method: [#{self.miq_callback[:method_name]}], skipping")
        end
      rescue => err
        $log.error("#{log_prefix} #{MiqQueue.format_short_log_msg(self)}: #{err}")
        $log.debug("#{log_prefix} backtrace: #{err.backtrace.join("\n")}")
      end
    else
      $log.warn "#{log_prefix} #{MiqQueue.format_short_log_msg(self)}, Callback is not well-defined, skipping"
    end
  end

  def requeue(options = {})
    options.reverse_merge!(self.attributes.symbolize_keys)
    MiqQueue.put(options)
  end

  def check_for_timeout(log_prefix = "MIQ(MiqQueue.check_for_timeout)", grace = 10.seconds, timeout = self.msg_timeout.seconds)
    if self.state == 'dequeue' && Time.now.utc > (self.updated_on + timeout.seconds + grace.seconds).utc
      msg = " processed by #{self.handler.format_full_log_msg}" unless self.handler.nil?
      $log.warn("#{log_prefix} Timed Out Active #{MiqQueue.format_short_log_msg(self)}#{msg} after #{Time.now.utc - self.updated_on} seconds")
      self.destroy rescue nil
    end
  end

  def finished?
    FINISHED_STATES.include?(self.state)
  end

  def unfinished?
    !finished?
  end

  def self.dev_null(id, data)
    msg = "#{LOG_PREFIX[:dev_null]} Id: #{id} delivered, data: \"#{data}\""
    $log.info msg
    puts      msg
  end

  def self.atStartup
    log_prefix = LOG_PREFIX[:atStartup]
    if File.exist?(@@delete_command_file)
      options = YAML::load(ERB.new(File.read(@@delete_command_file)).result)
      if options[:required_role].nil? || MiqServer.my_server(true).has_active_role?(options[:required_role])
        $log.info("#{log_prefix} Executing: [#{@@delete_command_file}], Options: [#{options.inspect}]")
        deleted = self.delete_all(options[:conditions])
        $log.info("#{log_prefix} Executing: [#{@@delete_command_file}] complete, #{deleted} rows deleted")
      end
      File.delete(@@delete_command_file)
    end

    $log.info("#{log_prefix} Cleaning up queue messages...")
    MiqQueue.where(:state => STATE_DEQUEUE).each do |message|
      if message.handler.nil?
        $log.warn("#{log_prefix} Cleaning message in dequeue state without worker: #{self.format_full_log_msg(message)}")
      else
        handler_server = message.handler            if message.handler.kind_of?(MiqServer)
        handler_server = message.handler.miq_server if message.handler.kind_of?(MiqWorker)
        next unless handler_server == MiqServer.my_server

        $log.warn("#{log_prefix} Cleaning message: #{self.format_full_log_msg(message)}")
      end
      message.update_attributes(:state => STATE_ERROR) rescue nil
    end
    $log.info("#{log_prefix} Cleaning up queue messages... Complete")
  end

  def self.format_full_log_msg(msg)
    "Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{MiqPassword.sanitize_string(msg.args.inspect)}"
  end

  def self.format_short_log_msg(msg)
    "Message id: [#{msg.id}]"
  end

  # @return [Hash<String,Hash<Symbol,FixedNum>> wait times for the next and last items in the queue grouped by role
  # TODO: better leverage SQL using group / partition
  def self.wait_times_by_role
    now = Time.now.utc
    dates = where(:state => STATE_READY)
           .select("created_on, role")
           .order("priority, id").to_a
           .each.with_object({}) { |c, h| (h[c.role] ||=[]) << c.created_on }

    dates.each.with_object({}) { |(role, created_ons), h|
      h[role]= { :next => (now - created_ons.last), :last => (now - created_ons.first) }
    }
  end

  def get_worker
    self.handler.kind_of?(MiqWorker) ? self.handler : nil
  end

  def self.get_worker(task_id)
    msg = self.find_by_task_id(task_id)
    return nil if msg.nil?
    msg.get_worker
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
end #Class MiqQueue
