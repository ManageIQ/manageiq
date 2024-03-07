class ManageIQ::Providers::PhysicalInfraManager::Vm < Vm
  default_value_for :cloud, false

  def self.display_name(number = 1)
    n_('Virtual Machine', 'Virtual Machines', number)
  end
end
