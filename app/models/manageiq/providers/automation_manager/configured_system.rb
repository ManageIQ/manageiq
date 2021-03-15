class ManageIQ::Providers::AutomationManager::ConfiguredSystem < ::ConfiguredSystem
  virtual_column  :inventory_root_group_name, :type => :string

  def inventory_root_group_name
    inventory_root_group.name
  end
end
