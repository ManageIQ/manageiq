module Service::RetirementManagement
  extend ActiveSupport::Concern
  include RetirementMixin

  module ClassMethods
    def retirement_check
      services = Service.where("retires_on IS NOT NULL OR retired = ?", true)
      services.each(&:retirement_check)
    end
  end

  def before_retirement
    children.each(&:retire_now)
  end

  def retire_service_resources
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
