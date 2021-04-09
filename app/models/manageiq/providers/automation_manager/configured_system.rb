class ManageIQ::Providers::AutomationManager::ConfiguredSystem < ::ConfiguredSystem
  virtual_column  :inventory_root_group_name, :type => :string, :uses => :inventory_root_group

  def inventory_root_group_name
    inventory_root_group.name
  end
end
