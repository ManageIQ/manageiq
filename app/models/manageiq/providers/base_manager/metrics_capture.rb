class ManageIQ::Providers::BaseManager::MetricsCapture
  include Vmdb::Logging

  attr_reader :target, :ems
  def initialize(target, ems = nil)
    @target = target
    @ems = ems
  end

  def zone
    ems.zone
  end

  def my_zone
    ems.zone.name
  end

  # @param targets [Array<Object>] list of the targets for capture (from `capture_ems_targets`)
  # @param target_options [ Hash{Object => Hash{Symbol => Object}}] list of options indexed by target
  def queue_captures(targets, target_options)
    targets.each do |target|
      options = target_options[target] || {}
      interval_name = options[:interval] || perf_target_to_interval_name(target)
      target.perf_capture_queue(interval_name, options)
    rescue => err
      _log.warn("Failed to queue perf_capture for target [#{target.class.name}], [#{target.id}], [#{target.name}]: #{err}")
    end
  end

  private

  def perf_target_to_interval_name(target)
    case target
    when Host, VmOrTemplate then                       "realtime"
    when ContainerNode, Container, ContainerGroup then "realtime"
    when Storage then                                  "hourly"
    end
  end
end
