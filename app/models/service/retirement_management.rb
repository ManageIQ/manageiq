module Service::RetirementManagement
  extend ActiveSupport::Concern
  include RetirementMixin

  def before_retirement
    children.each(&:retire_now)
  end

  def retire_service_resources
    # TODO: delete me per https://github.com/ManageIQ/manageiq/pull/16933#discussion_r175805070
    return
    direct_service_children.each(&:retire_service_resources)

    service_resources.each do |sr|
      if sr.resource.respond_to?(:retire_now)
        $log.info("Retiring service resource for service: #{name} resource ID: #{sr.id}")
        sr.resource.retire_now(retirement_requester)
      end
    end
  end

  def automate_retirement_entrypoint
    r = service_template.resource_actions.detect { |ra| ra.action == 'Retirement' } unless service_template.nil?
    state_machine_entry_point = r.try(:fqname)
    $log.info("get_retirement_entrypoint returning state machine entry point: #{state_machine_entry_point}")
    state_machine_entry_point
  end
end
