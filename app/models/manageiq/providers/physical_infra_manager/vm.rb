class ManageIQ::Providers::PhysicalInfraManager::Vm < Vm
  attribute :cloud, :default => false

  def self.display_name(number = 1)
    n_('Virtual Machine', 'Virtual Machines', number)
  end
end
