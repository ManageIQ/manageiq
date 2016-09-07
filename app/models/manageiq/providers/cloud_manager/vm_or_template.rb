class ManageIQ::Providers::CloudManager::VmOrTemplate < ActsAsArScope
  class << self
    delegate :all_orphaned, :all_archived, :to => :aar_scope
    delegate :klass, :to => :aar_scope, :prefix => true
  end

  def self.aar_scope
    ::VmOrTemplate.where(:type => vm_descendants)
  end

  def self.vm_descendants
    ManageIQ::Providers::CloudManager::Vm.descendants +
      ManageIQ::Providers::CloudManager::Template.descendants
  end
end
