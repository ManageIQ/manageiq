module VmOrTemplate::RetirementManagement
  extend ActiveSupport::Concern
  include RetirementMixin

  module ClassMethods
    def retirement_check
      zone    = MiqServer.my_server.zone
      ems_ids = zone.ext_management_systems(:select => :id).collect(&:id).flatten
      vms     = Vm.where("(retires_on IS NOT NULL OR retired = ?) AND ems_id IN (?)", true, ems_ids)
      vms.each(&:retirement_check)
    end
  end

  def retired_validated?
    ['off', 'never'].include?(state)
  end

  def retired_invalid_reason
    "has state: [#{state}]"
  end
end
