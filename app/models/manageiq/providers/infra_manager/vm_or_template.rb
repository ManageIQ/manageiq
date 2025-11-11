class ManageIQ::Providers::InfraManager::VmOrTemplate < ActsAsArScope
  class << self
    delegate :orphaned, :archived, :to => :aar_scope
  end

  def self.aar_scope
    ::VmOrTemplate.where(:type => vm_descendants.collect(&:to_s))
  end

  def self.vm_descendants
    ManageIQ::Providers::InfraManager::Vm.descendants +
      ManageIQ::Providers::InfraManager::Template.descendants
  end
end
