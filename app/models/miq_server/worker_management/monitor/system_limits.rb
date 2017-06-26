require 'miq-system'

module MiqServer::WorkerManagement::Monitor::SystemLimits
  extend ActiveSupport::Concern

  TYPE_TO_DEFAULT_ALGORITHM = {
    :kill  => :used_swap_percent_gt_value,
    :start => :used_swap_percent_lt_value
  }

  def kill_workers_due_to_resources_exhausted?
    return false if MiqEnvironment::Command.is_container?
    options = worker_monitor_settings[:kill_algorithm].merge(:type => :kill)
    invoke_algorithm(options)
  end

  def enough_resource_to_start_worker?(worker_class)
    return true if MiqEnvironment::Command.is_container?
    # HACK, sync_config is done in the server, while this method is called from miq_worker
    # This method should move to the worker and the server should pass the settings.
    sync_config if worker_monitor_settings.nil? || child_worker_settings.nil?

    # Pass along the start_algorithm, the worker, and the worker's settings overriding any worker monitor settings
    base    = {:type => :start, :worker_name => worker_class.name}
    monitor = worker_monitor_settings[:start_algorithm]
    child   = child_worker_settings.fetch_path(worker_class.settings_name, :start_algorithm) || {}
    options = base.merge(monitor).merge(child)

    invoke_algorithm(options)
  end

  def kill_algorithm_used_swap_percent_gt_value(options)
    begin
      value = options[:value].nil? ? 60 : options[:value]
      sys = MiqSystem.memory

      return false if sys[:SwapTotal].nil? || sys[:SwapFree].nil? || sys[:MemFree].nil? || sys[:SwapTotal] == 0
      used = sys[:SwapTotal] - sys[:SwapFree] - sys[:MemFree]
      pct_used = used / sys[:SwapTotal].to_f * 100
    rescue => err
      _log.warn("#{err.message}, calculating percent of swap space used")
      return false
    end

    if pct_used >= value
      _log.warn("System memory usage has exceeded #{value}% of swap: Total: [#{sys[:SwapTotal]}], Used: [#{used}]")
      return true
    end
    false
  end

  def start_algorithm_used_swap_percent_lt_value(options)
    begin
      value = options[:value].nil? ? 40 : options[:value]
      sys = MiqSystem.memory

      return true if sys[:SwapTotal].nil? || sys[:SwapFree].nil? || sys[:MemFree].nil? || sys[:SwapTotal] == 0
      used = sys[:SwapTotal] - sys[:SwapFree] - sys[:MemFree]
      pct_used = used / sys[:SwapTotal].to_f * 100
    rescue => err
      _log.warn("Allowing worker: [#{options[:worker_name]}] to start due to error: #{err.message}, calculating percent of swap space used")
      return true
    end

    unless pct_used <= value
      _log.error("Not allowing worker [#{options[:worker_name]}] to start since system memory usage has exceeded #{value}% of swap: Total: [#{sys[:SwapTotal]}], Used: [#{used}]")
      return false
    end
    true
  end

  def start_algorithm_used_swap_percent_lt_value_and_free_memory_gt_half_worker_memory_threshold(options)
    return false unless start_algorithm_used_swap_percent_lt_value(options)

    # TODO: this is completely inconsistent, currently, this method assumes a config like:
    # :start_algorithm:
    #   :name: :used_swap_percent_lt_value_and_free_memory_gt_half_worker_memory_threshold
    #   :value: 60
    #   :settings:
    #     :memory_threshold: 100.megabytes
    #
    # If this is to be used, it makes more sense to specify the settings without the nested hash:
    #
    # :start_algorithm:
    #   :name: :used_swap_percent_lt_value_and_free_memory_gt_half_worker_memory_threshold
    #   :value: 60
    #   :memory_threshold: 100.megabytes

    # Is this code even used?  How would a user know how to configure this?
    # Delete this?
    settings = options[:settings]
    if settings.nil?
      _log.warn("Allowing worker: [#{options[:worker_name]}] to start since its theshold settings were not found!")
      return false
    end

    value = settings[:memory_threshold]
    unless value.kind_of?(Integer)
      _log.warn("Allowing worker: [#{options[:worker_name]}] to start since the threshold is invalid: [#{value}], type: [#{value.class.name}]")
      return false
    end

    value /= 2  # The start limit is half the max
    sys = MiqSystem.memory
    result = (sys[:MemFree].nil? || sys[:MemFree] > value)
    _log.error("Not allowing worker [#{options[:worker_name]}] to start since free memory [#{sys[:MemFree]}] is less than half the worker threshold [#{value}]") unless result
    result
  end

  def invoke_algorithm(options)
    _log.debug("Invoke algorithm started with options: [#{options.inspect}]")
    name = options[:name]
    type = options[:type]
    full_algorithm_name = build_algorithm_name(name, type)

    _log.debug("Executing [#{type}] algorithm: [#{name}]")
    res = send(full_algorithm_name, options)
    _log.debug("Executing [#{type}] algorithm: [#{name}] completed with result: [#{res}]")
    res
  end

  def build_algorithm_name(name, type)
    real_algorithm_name = "#{type}_algorithm_#{name}" if name && type
    unless real_algorithm_name && self.respond_to?(real_algorithm_name)
      default = TYPE_TO_DEFAULT_ALGORITHM[type]
      _log.warn("Using default algorithm: [#{default}] since [#{name}] is not a valid algorithm")
      real_algorithm_name = "#{type}_algorithm_#{default}"
      unless respond_to?(real_algorithm_name)
        raise _("Default algorithm [%{default}] not found!") % {:default => default}
      end
    end
    real_algorithm_name
  end
end
