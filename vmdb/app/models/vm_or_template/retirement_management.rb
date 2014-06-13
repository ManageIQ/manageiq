module VmOrTemplate::RetirementManagement
  extend ActiveSupport::Concern
  include RetirementMixin

  module ClassMethods
    def retirement_check
      zone    = MiqServer.my_server.zone
      ems_ids = zone.ext_management_systems(:select => :id).collect { |e| e.id }.flatten
      vms     = Vm.all(:conditions => ["(retires_on IS NOT NULL OR retired = ?) AND ems_id IN (?)", true, ems_ids])
      vms.each { |vm| vm.retirement_check }
    end
  end

  def retired_validated?
    ['off', 'never'].include?(self.state)
  end

  def retired_invalid_reason
    "has state: [#{self.state}]"
  end

end
