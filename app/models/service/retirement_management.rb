module Service::RetirementManagement
  extend ActiveSupport::Concern
  include RetirementMixin

  def before_retirement
    children.each(&:retire_now)
  end

  def automate_retirement_entrypoint
    r = service_template.resource_actions.detect { |ra| ra.action == 'Retirement' } unless service_template.nil?
    state_machine_entry_point = r.try(:fqname)
    $log.info("get_retirement_entrypoint returning state machine entry point: #{state_machine_entry_point}")
    state_machine_entry_point
  end
end
