class EmsEvent
  module Automate
    extend ActiveSupport::Concern

    def refresh(*targets)
      targets = targets.flatten
      return if targets.blank?

      refresh_targets = targets.collect { |t| get_target("#{t}_refresh_target") unless t.blank? }.compact.uniq
      return if refresh_targets.empty?

      EmsRefresh.queue_refresh(refresh_targets)
    end

    def policy(target_str, policy_event, param)
      log_header = "MIQ(#{self.class.name}##{__method__})"
      $log.debug("#{log_header} ems: [#{ems_id}]")
      return if ems_id.nil?

      target, policy_event, policy_src = parse_policy_parameters(target_str, policy_event, param)
      return if target.nil? || policy_event.nil? || policy_src.nil?

      inputs = {
        target.class.name.downcase.singularize.to_sym => target,
        policy_src.class.table_name.to_sym            => policy_src,
        :ems_event                                    => self
      }
      begin
        MiqEvent.raise_evm_event(target, policy_event, inputs)
      rescue => err
        $log.log_backtrace(err)
      end
    end

    def scan(*targets)
      log_header = "MIQ(#{self.class.name}##{__method__})"
      $log.debug("#{log_header} Targets: [#{targets.inspect}]")

      missing_targets = targets.each_with_object([]) do |t, arr|
        target = get_target(t)
        if target.nil?
          # Queue that target for refresh instead
          $log.info("#{log_header} Unable to find target [#{t}].  Queueing for refresh.")
          arr << t
        else
          $log.info("#{log_header} Scanning [#{t}] [#{target.id}] name: [#{target.name}]")
          target.scan
        end
      end

      unless missing_targets.empty?
        $log.info("#{log_header} Performing refresh on the targets that were not found #{missing_targets.inspect}.")
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

    def src_vm_disconnect_storage
      call("src_vm", "disconnect_storage")
    end

    def src_vm_refresh_on_reconfig
      call("src_vm", "refresh_on_reconfig")
    end

    private

    def parse_policy_parameters(target_str, policy_event, param)
      log_header = "MIQ(#{self.class.name}##{__method__})"

      target         = get_target(target_str)     unless target_str.blank?
      policy_event ||= event_type
      policy_src     = parse_policy_source(target, param) if target

      $log.debug("#{log_header} Target: [#{target_str}], Policy event: [#{policy_event}]")
      $log.debug("#{log_header} Target object: [#{target.inspect}]")
      $log.debug("#{log_header} Policy source: [#{policy_src}]")

      return if target.nil? || policy_event.nil? || policy_src.nil?
      [target, policy_event, policy_src]
    end

    def parse_policy_source(target, param)
      log_header = "MIQ(#{self.class.name}##{__method__})"
      param.blank? ? ext_management_system : target.send(param)
    rescue => err
      $log.warn "#{log_header} Error: #{err.message}, getting policy source, skipping policy evaluation"
    end

    def call(target_str, method, options = {})
      return if target_str.nil? || method.nil?
      log_header = "MIQ(#{self.class.name}##{__method__})"

      target = target_original = get_target(target_str)
      if target.nil?
        $log.info "#{log_header} Unable to find target [#{target_str}].  Performing refresh."
        return refresh(target_str)
      end

      methods = method.split('.').collect { |m| [m] }
      methods[-1] << options[:param] if options.key?(:param)

      $log.info("#{log_header} Calling method [#{target.class}, #{target.id}].#{methods}")
      methods.each { |m| target = target.send(*m) }

      target_original.send(:save!) if options[:save] == true
    end
  end
end
