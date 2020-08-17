class EmsEvent
  module Automate
    extend ActiveSupport::Concern

    def manager_refresh(sync: false)
      refresh_targets = manager_refresh_targets

      return if refresh_targets.empty?

      EmsRefresh.queue_refresh(refresh_targets, nil, :create_task => sync)
    end

    def refresh(*targets, sync)
      return if ext_management_system&.supports_streaming_refresh?

      targets = targets.flatten
      return if targets.blank?

      refresh_targets = targets.collect { |t| get_target("#{t}_refresh_target") unless t.blank? }.compact.uniq
      return if refresh_targets.empty?

      EmsRefresh.queue_refresh(refresh_targets, nil, :create_task => sync)
    end

    def policy(target_str, policy_event, param = nil)
      _log.debug("ems: [#{ems_id}]")
      return if ems_id.nil?

      target, policy_event, policy_src = parse_policy_parameters(target_str, policy_event, param)
      return if target.nil? || policy_event.nil? || policy_src.nil?

      inputs = {
        policy_src.class.table_name.to_sym            => policy_src,
        :ems_event                                    => self
      }
      begin
        MiqEvent.raise_evm_event(target, policy_event, inputs)
      rescue => err
        _log.log_backtrace(err)
      end
    end

    def scan(*targets)
      _log.debug("Targets: [#{targets.inspect}]")

      missing_targets = targets.each_with_object([]) do |t, arr|
        target = get_target(t)
        if target.nil?
          # Queue that target for refresh instead
          _log.info("Unable to find target [#{t}].  Queueing for refresh.")
          arr << t
        else
          _log.info("Scanning [#{t}] [#{target.id}] name: [#{target.name}]")
          target.scan
        end
      end

      unless missing_targets.empty?
        _log.info("Performing refresh on the targets that were not found #{missing_targets.inspect}.")
        refresh(*missing_targets)
      end
    end

    def src_vm_as_template(flag)
      options = {
        :param => flag,
        :save  => true
      }

      call("src_vm", "template=", options)
    end

    def change_event_target_state(target_str, param)
      options = {
        :param => param,
        :save  => true
      }

      target = get_target(target_str)
      method = target.respond_to?(:raw_power_state=) ? "raw_power_state=" : "state="
      call(target_str, method, options)
    end

    def src_vm_destroy_all_snapshots
      call("src_vm", "snapshots.destroy_all")
    end

    private

    def parse_policy_parameters(target_str, policy_event, param)
      target         = get_target(target_str)     unless target_str.blank?
      policy_event ||= event_type
      policy_src     = parse_policy_source(target, param) if target

      _log.warn("Unable to find target [#{target_str}], skipping policy evaluation") if target.nil?
      _log.debug("Target: [#{target_str}], Policy event: [#{policy_event}]")
      _log.debug("Target object: [#{target.inspect}]")
      _log.debug("Policy source: [#{policy_src}]")

      [target, policy_event, policy_src]
    end

    def parse_policy_source(target, param)
      param.blank? ? ext_management_system : target.send(param)
    rescue => err
      _log.warn("Error: #{err.message}, getting policy source, skipping policy evaluation")
    end

    def call(target_str, method, options = {})
      return if target_str.nil? || method.nil?

      target = target_original = get_target(target_str)
      if target.nil?
        _log.info("Unable to find target [#{target_str}].  Performing refresh.")
        return refresh(target_str)
      end

      methods = method.split('.').collect { |m| [m] }
      methods[-1] << options[:param] if options.key?(:param)

      _log.info("Calling method [#{target.class}, #{target.id}].#{methods}")
      methods.each { |m| target = target.send(*m) }

      target_original.send(:save!) if options[:save] == true
    end
  end
end
